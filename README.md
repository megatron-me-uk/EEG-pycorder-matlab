EEG-pycorder-matlab
===================

Read data into Matlab from Pycorder


data = EEG_read( [FileName [, PathName]] )
   This function reads in all data associated with an `.eeg` file produced
   by the Pycorder EEG data capture program. It currently requires three
   files to be present in the directory: *.eeg, *.vhdr, *.vmrk
   
   Unfortunately Pycorder follows some bizarre corruption of the INI file
   format for its header files. This means we have to parse them with some
   arcane rules that are set out in the source code.

   If no inputs are supplied an interactive dialog will open to allow
   selection of the correct file.
   
   The resulting output `data` is a structure with three fields:
 conf, marker, raw
   
   conf is a structure containing the contents of the vhdr header file.

   marker is a structure containing the contents of the vmrk marker file.
   This includes all trigger signals from the parallel port plus any
   button presses on the ActiCHamp.

   raw contains the raw data that has been parsed from the .eeg file. This
   will be shaped as NoChannels by NoSamples. In order to convert this raw
   data into meaningful units, various fields from conf will be required
   (e.g. SamplingInterval [microseconds] and channel Voltage scale
   which can be found in each Ch field of conf. Note that the Pycorder
   software does not correct for the bip2aux amplification so Voltage
   units may be a factor of 100 too high!).

 svt10 05/12/2012
