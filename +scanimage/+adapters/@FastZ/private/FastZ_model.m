%% FastZ
frameClockIn = '';                  % String: One of {PFI0..15, ''} to which external frame trigger is connected. Leave empty if DAQ device is in main PXI chassis

%FastZ hardware used for fast axial motion, supporting fast stacks and/or volume imaging
%fastZControllerType must be specified to enable this feature. 
%Specifying fastZControllerType='useMotor2' indicates that motor2 ControllerType/StageType/COMPort/etc will be used.
fastZControllerType = '';           % String: If supplied, one of {'useMotor2', 'pi.e665', 'pi.e816', 'npoint.lc40x'}. 
fastZCOMPort = [];                  % Numeric: Integer identifying COM port for controller, if using serial communication
fastZBaudRate = [];                 % Numeric: Value identifying baud rate of serial communication. If empty, default value for controller used.

%Some FastZ hardware requires or benefits from use of an analog output used to control sweep/step profiles
%If analog control is used, then an analog sensor (input channel) must also be configured
fastZAODeviceName = '';             % String: Specifies device name containing AO channel used for FastZ control
fastZAOChanID = [];                 % Numeric: Scalar integer indicating AO channel used for FastZ control
fastZAIDeviceID = '';               % String: Specifies device name containig AI channel used for FastZ position sensor
fastZAIChanID = [];                 % Numeric: Scalar integer indicating AI channel used for FastZ sensor