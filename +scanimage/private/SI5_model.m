%% ScanImage
simulated = false;                  % Logical: If true, activates simulated mode. For normal operation, set to 'false'. For operation without NI hardware attached, set to 'true'.

scannerHardwareType = 'standard';   % String: One of {'standard' 'ecu1' 'bscope2'}
primaryPxiChassisNum = 1;           % Numeric: ID of the PXI chassis that contains the FlexRIO FPGA, digitizer module, and DAQ board(s)
digitalIODeviceName = 'PXI1Slot3';  % String: Device name of the DAQ board or FlexRIO FPGA that is used for digital inputs/outputs (triggers/clocks/shutters etc). If it is a DAQ device, it must be installed in the same PXI chassis as the FlexRIO Digitizer

nominalResScanFreq = 7910;          % Numeric: Nominal frequency of the resonant scanner, in Hz