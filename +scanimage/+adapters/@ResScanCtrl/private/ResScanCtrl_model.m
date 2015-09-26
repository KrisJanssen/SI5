%% ResScanCtrl
scanCtrlDeviceName = 'PXI1Slot3';   % String: Identifies the NI-DAQ board to be used to control the resonant scanner box and galvo driver. The name of the DAQ-Device can be seen in NI MAX. e.g. 'Dev1' or 'PXI1Slot3'. This DAQ board needs to be installed in the same PXI chassis as the FPGA board specified in section %% ResonantAcq
resonantZoomAOChanID = 0;           % Numeric: ID of the analog output channel to be used to control the Resonant Scanner Zoom level.
galvoAOChanID = 1;                  % Numeric: ID of the analog output channel to be used to control the Galvo.

chanCtrMeasResPeriod = 0;           % Numeric: ID of the counter channel for measuring the resonant scanner period

galvoVoltsPerOpticalDegree = 1.0;   % Numeric [V/deg]: Galvo conversion factor from optical degrees to volts
rScanVoltsPerOpticalDegree = 0.33;  % Numeric [V/deg]: Resonant scanner conversion factor from (peak-to-peak) optical degrees to volts
refAngularRange = 15;               % Numeric [deg]: Optical degrees for resonant scanner and galvo at zoom level = 1
galvoParkDegrees = 8;               % Numeric [deg]: Optical degrees from center position for galvo to park at when scanning is inactive
resonantScannerSettleTime = 0;      % Numeric [sec]: Time to wait for the resonant scanner to reach its desired frequency after an update of the zoomFactor