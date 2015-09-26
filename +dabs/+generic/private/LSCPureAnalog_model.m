%% LSC Pure Analog
commandVoltsPerMicron = []; % Conversion factor for command signal to analog linear stage controller
sensorVoltsPerMicron = []; % Conversion signal for sensor signal from analog linear stage controller

commandVoltsOffset = 0; % Offset value, in volts, for command signal to analog linear stage controller
sensorVoltsOffset = 0; % Offset value, in volts, for sensor signal from analog linear stage controller
            
analogCmdBoardID = ''; % String specifying NI board identifier (e.g. 'Dev1') containing AO channel for LSC control
analogCmdChanIDs = []; % Scalar indicating AO channel number (e.g. 0) used for analog LSC control
analogSensorBoardID = ''; % String specifying NI board identifier (e.g. 'Dev1') containing AI channel for LSC position sensor
analogSensorChanIDs = []; % Scalar indicating AI channel number (e.g. 0) used for analog LSC position sensor
