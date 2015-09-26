%% ResonantAcq
fpgaModuleType = 'NI7961';          % String: Type of FlexRIO FPGA module in use. One of {'NI7961' 'NI7975'}
digitizerModuleType = 'NI5732';     % String: Type of digitizer adapter module in use. One of {'NI5732' 'NI5734'}
rioDeviceID = 'RIO0';               % String: FlexRIO Device ID as specified in MAX. If empty, defaults to 'RIO0'
channelsInvert = false;             % Logical: If true, the input signal is inverted (i.e., more negative for increased light signal)