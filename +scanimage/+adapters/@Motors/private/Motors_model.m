%% Motors
%Motor used for X/Y/Z motion, including stacks.
%motorDimensions & motorControllerType must be specified to enable this feature.
motorDimensions = '';               % String: If supplied, one of {'XYZ', 'XY', 'Z'}. Defaults to 'XYZ'.
motorControllerType = '';           % String: If supplied, one of  {'sutter.mp285', 'sutter.mpc200', 'thorlabs.bscope2', 'pi.e665', 'pi.e816', 'npoint.lc40x'}
motorStageType = '';                % String: Some controller require a valid stageType be specified
motorCOMPort = [];                  % Numeric: Integer identifying COM port for controller, if using serial communication
motorBaudRate = [];                 % Numeric: Value identifying baud rate of serial communication. If empty, default value for controller used.
motorZDepthPositive = true;         % Logical: Indicates if larger Z values correspond to greater depth
motorPositionDeviceUnits = [];      % Numeric [m]: 1x3 array specifying, in meters, raw units in which motor controller reports position. If unspecified, default positionDeviceUnits for stage/controller type presumed.
motorVelocitySlow = [];             % Numeric: Velocity to use for moves smaller than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.
motorVelocityFast = [];             % Numeric: Velocity to use for moves larger than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.

%Secondary motor for Z motion, allowing either XY-Z or XYZ-Z hybrid configuration
motor2ControllerType = '';          % String: If supplied, one of {'sutter.mp285', 'sutter.mpc200', 'pi.e665', 'pi.e816', 'npoint.lc40x'}
motor2StageType = '';               % String: Some controller require a valid stageType be specified
motor2COMPort = [];                 % Numeric: Integer identifying COM port for controller, if using serial communication
motor2BaudRate = [];                % Numeric: Value identifying baud rate of serial communication. If empty, default value for controller used.
motor2ZDepthPositive = true;        % Logical: Indicates if larger Z values correspond to greater depth
motor2PositionDeviceUnits = [];     % Numeric [m]: 1x3 array specifying, in meters, raw units in which motor controller reports position. If unspecified, default positionDeviceUnits for stage/controller type presumed.
motor2VelocitySlow = [];            % Numeric: Velocity to use for moves smaller than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.
motor2VelocityFast = [];            % Numeric: Velocity to use for moves larger than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.

%Some motor controllers require a delay after nominal move completion in order to fully settle on target position
%Currently, any specified delay is applied following either primary or secondary controller motor moves
moveCompleteDelay = 0;              % Numeric [s]: Delay from when stage controller reports move is complete until move is actually considered complete. Allows settling time for motor
