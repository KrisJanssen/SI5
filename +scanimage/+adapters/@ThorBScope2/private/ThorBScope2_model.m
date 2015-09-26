%% Thor BScope2
ecu2ComPort = [];                   % Numeric: COM port for ECU2 commands
mcm5000ComPort = [];                % Numeric: COM port for MCM5000 controller commands
hasRotation = false;                % Logical: If true, stage controller supports rotation axis
acqStatusUpdateInterval = 0.5;      % Numeric [sec]: Rate at which to update the pmt statuses during an acquisition