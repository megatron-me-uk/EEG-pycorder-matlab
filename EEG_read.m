%data = EEG_read( [FileName [, PathName]] )
%   This function reads in all data associated with an `.eeg` file produced
%   by the Pycorder EEG data capture program. It currently requires three
%   files to be present in the directory: *.eeg, *.vhdr, *.vmrk
%   
%   Unfortunately Pycorder follows some bizarre corruption of the INI file
%   format for its header files. This means we have to parse them with some
%   arcane rules that are set out in the source code.
%
%   If no inputs are supplied an interactive dialog will open to allow
%   selection of the correct file.
%   
%   The resulting output `data` is a structure with three fields:
%   conf, marker, raw
%   
%   conf is a structure containing the contents of the vhdr header file.
%
%   marker is a structure containing the contents of the vmrk marker file.
%   This includes all trigger signals from the parallel port plus any
%   button presses on the ActiCHamp.
%
%   raw contains the raw data that has been parsed from the .eeg file. This
%   will be shaped as NoChannels by NoSamples. In order to convert this raw
%   data into meaningful units, various fields from conf will be required
%   (e.g. SamplingInterval [microseconds] and channel Voltage scale
%   which can be found in each Ch field of conf. Note that the Pycorder
%   software does not correct for the bip2aux amplification so Voltage
%   units may be a factor of 100 too high!).
%
% svt10 05/12/2012
function data = EEG_read( varargin )
PathName='';
if(nargin==0)
    %interactive mode
    [FileName,PathName,FilterIndex] = uigetfile('*.eeg');
    if(FilterIndex==0)
        fprintf('Cancelled.\n');
        data='Cancelled';
        return
    end
else
    FileName=varargin{1};
    if(nargin>=2)
        PathName=varargin{2};
        if(PathName(end)~='/')
            %ensure we can stitch FileName to PathName 
            PathName=[PathName '/'];
        end
    end
end
%Parse accompanying files
data.conf=parseHeader([PathName FileName(1:end-4) '.vhdr']);
data.markers=parseMarkers([PathName FileName(1:end-4) '.vmrk']);
%Read data
fid=fopen([PathName FileName]);
if(numel(data.conf.channelVec)==1)
    data.raw=fread(fid,'float32')';
elseif(numel(data.conf.channelVec)>1)
    data.raw=fread(fid,[numel(data.conf.channelVec) Inf],'float32');
else
    fprintf('EEG_read says "PANIC!"\n');
    fprintf('No channels detected...\n');
end
fclose(fid);
end

%%Helpers
function conf=parseHeader(fname)
%read Header File. This contains configuration information
conf=parseArbitrary(fname);
if(strcmp(conf.version,'Not Found'))
    %If we didn't find the file, make something up...
    conf.channelVec=[1];
    return
end
%find channels from structure
conf.channelVec=[];
for i=1:numel(fields(conf))
    %I think this should always read channels 1:NoChannels but let's
    %handle arbitrary channel numbering just in case.
    if(isfield(conf,['Ch' num2str(i)]))
        conf.channelVec=[conf.channelVec i];
        %Parse a numerical value from scaling factor.
        conf.(['Ch' num2str(i)]){2}=str2double(conf.(['Ch' num2str(i)]){2});
    end
end
%Check for weird things that will break our code later on.
if(~isfield(conf,'BinaryFormat')||~strcmp(conf.BinaryFormat,'IEEE_FLOAT_32'))
    fprintf('parseHeader says "PANIC!"\n');
    fprintf('We probably have the wrong binary format...\n');
end
if(~isfield(conf,'SamplingInterval'))
    fprintf('parseHeader says "PANIC!"\n');
    fprintf('We have no sampling rate...\n');
else
    %Parse a numerical value from SamplingInterval
    conf.SamplingInterval=str2double(conf.SamplingInterval);
end
if(~isfield(conf,'NumberOfChannels'))
    fprintf('parseHeader says "PANIC!"\n');
    fprintf('We have no channel count...\n');
else
    %Parse a numerical value from NumberOfChannels
    conf.NumberOfChannels=str2double(conf.NumberOfChannels);
end

end

function markers=parseMarkers(fname)
%read Marker File. This contains marker information (from parallel port or
%button on ActiCHamp.
markers=parseArbitrary(fname);
fieldz=fields(markers);
%Place an arbitrary z in the variable name in revenge for american english
%in all MatLab functions.
for i=1:numel(fieldz)
    %Find all Markers within the structure.
    temp=markers.(fieldz{i});
    if(iscell(temp))
        %This is a marker (we hope...)
        temp{1}(isspace(temp{1}))=[];
        temp{2}(isspace(temp{2}))=[];
        %Remove spaces as they cause problems in variable names
        if(strcmp(temp{1},'NewSegment'))
            %MatLab strtok is nonsensical so we have to special case this.
            %It should provide an empty [] value between two commas but
            %instead pretends it didn't see it...
            %Reorganise markers into matrices by type
            if(isfield(markers,temp{1}))
                %If we have already seen this marker type
                %All of these things should be numerical.
                %TODO check if they actually fit within a double. Losing
                %information here would be silly.
                markers.(temp{1}){end+1}=[...
                     ...%The next one is a datestamp in this format:
                     ...%YYYYMMDDHHmmssuuuuuu
                     ...%No timezone is specified but do we care?
                     temp{5}(1:4) '-' temp{5}(5:6) '-' temp{5}(7:8) 'T'...
                     temp{5}(9:10) ':' temp{5}(11:12) ':' temp{5}(13:14)...
                     '.' temp{5}(15:end) ];
            else
                %If we haven't already seen this marker type
                %All of these things should be numerical.
                markers.(temp{1}){1}=[...
                     ...%The next one is a datestamp in this format:
                     ...%YYYYMMDDHHmmssuuuuuu
                     temp{5}(1:4) '-' temp{5}(5:6) '-' temp{5}(7:8) 'T'...
                     temp{5}(9:10) ':' temp{5}(11:12) ':' temp{5}(13:14)...
                     '.' temp{5}(15:end) ];
            end
        else
            %I bet this will break at some point. Maybe I should be more
            %specific about the types of markers that I can handle here...
            if(isfield(markers,temp{1}))
                %If we have already seen this marker type
                %All of these things should be numerical.
                if(isfield(markers.(temp{1}),temp{2}))
                    %If we have already seen this perticular marker
                    %All of these things should be numerical.
                    markers.(temp{1}).(temp{2})=[...
                        markers.(temp{1}).(temp{2})...
                        [str2double(temp{3});...
                         str2double(temp{4});str2double(temp{5})]];
                else
                    %If we haven't already seen this particular marker
                    %All of these things should be numerical.
                    markers.(temp{1}).(temp{2})=[...
                        str2double(temp{3});...
                        str2double(temp{4});str2double(temp{5})];
                end
            else
                %If we haven't already seen this marker type (and hence
                %haven't seen this particular marker either...)
                %All of these things should be numerical.
                markers.(temp{1})=struct(temp{2},...
                    [str2double(temp{3});...
                     str2double(temp{4});str2double(temp{5})]);
            end
        end
        %DEBUG Keep the original fields for checking the sanity of what we
        %have just done...
        if(isfield(markers,'old'))
            markers.old.(fieldz{i})=temp;
        else
            markers.old=struct();
            markers.old.(fieldz{i})=temp;
        end
        %END DEBUG
        markers=rmfield(markers,fieldz{i});
        %Remove the old fields. I prefer our newer shinier fields.
    end
end

end

function rStructure=parseArbitrary(fname)
fid=fopen(fname);
%Check we actually have a file
if(fid==-1)
    rStructure.version='Not Found';
    return
end
%Let's read a python config file...
%
%Unfortunately Pycorder does not follow the python standard... This may
%break in the future if Pycorder changes...
tline = fgetl(fid);
%First Line states version. We currently are compatible with Header File
%Version 1.0 and Marker File Version 1.0.
rStructure.version=tline;
if(~(strcmp(rStructure.version,...
        'Brain Vision Data Exchange Marker File, Version 1.0')...
     || ...
     strcmp(rStructure.version,...
        'Brain Vision Data Exchange Header File Version 1.0')...
    ))
    fprintf('parseArbitrary says "PANIC!"\n');
    fprintf('%s may not be supported.\n',rStructure.version);
end
%Now lets go through the rest of the file line by line.
CommentSection = 0;
%the comment section looks important, lets keep it
while(1)
    tline=fgetl(fid);
    if(isequal(tline,-1))
        break
    end
    %while not EOF
    if(numel(tline)==0||tline(1)==';')
        %Ignore commented lines
        continue
    end
    if(CommentSection)
        %the comment section looks important, lets keep it
        if(tline(1)=='['&&~strcmp(tline,'[Comment]'))
            %but if we have a new section which is not a comment section
            %then break this while loop and carry on parsing...
            CommentSection=0;
            continue
        end
        rStructure.Comment=[rStructure.Comment '\n' tline];
        continue
    end
    if(tline(1)=='[')
        % Ignore section headers
        if(strcmp(tline,'[Comment]'))
            CommentSection = 1;
            %Except the comment section which looks important
            if(~isfield(rStructure,'Comment'))
                rStructure.Comment='';
            end
        end
        continue
    end
    eq=strfind(tline,'=');
    %Everything else should be assigning values
    if(numel(eq)==0)
        %If not we have a problem...
        fprintf('parseArbitrary says "PANIC!"\n');
        fprintf('%s\n',tline);
        continue
    end
    if(numel(strfind(tline,',')))
        %Some variables are lists so handle them
        tokens = {};
        remains=tline(eq+1:end);
        while ~isempty(remains)
            [tok,remains] =strtok(remains,',');
            tokens{end+1} = tok;
        end
        rStructure.(tline(1:eq-1))=tokens;
    else
        %else just assign values as strings.
        %Numerical data will be handled later...
        rStructure.(tline(1:eq-1))=tline(eq+1:end);
    end
end
%DEBUG Go back and read a copy of the whole file for comparison.
fseek(fid,0,-1);
rStructure.DEBUG=fread(fid,'int8=>char')';
%END DEBUG
fclose(fid);
end
