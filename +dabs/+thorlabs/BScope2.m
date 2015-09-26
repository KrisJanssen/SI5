classdef BScope2 < dabs.interfaces.LinearStageController
    %  BSCOPE2
    %  Subclass of LSCSerial class to implement stage controller
    %  For Thor Labs B scope
    
    %% ABSTRACT PROPERTY REALIZATIONS (Devices.Interfaces.LinearStageController)
    properties (Constant,Hidden)
        nonblockingMoveCompletedDetectionStrategy = 'poll';
    end
  
    properties (SetAccess=protected,Dependent)
        isMoving;
        infoHardware;
    end
    
    properties (SetAccess=protected,Dependent,Hidden)
        positionAbsoluteRaw;
        velocityRaw; %vector; set not supported
        accelerationRaw = NaN; % n/a for bscope2
        invertCoordinatesRaw = false; % n/a for bscope2
        maxVelocityRaw;
        
        resolutionRaw = [0.5 0.5 0.1]; %Resolution, in um, in the current resolutionMode
    end    
    
    properties (SetAccess=protected,Hidden)
        positionDeviceUnits = 1e-6;
        velocityDeviceUnits = NaN; % velocity units are arbitrary
        accelerationDeviceUnits = NaN; % n/a for bscope2
    end
    
    
    %% CLASS-SPECIFIC PROPERTIES
    properties (Constant,Hidden)
        lscSupportedFirmwareVersions = {'1.3'};
        lscAvailableBaudRates = 9600;
        lscDefaultBaudRate = 9600;
        
        ECU2_SUPPORTED_SOFTWARE_VERSIONS = {'70-008-1.1'};
        ECU2_SUPPORTED_HARDWARE_VERSIONS = {'41-0027-006'};
        
        ECU2_SERIAL_BAUD_RATE    = 112500;
        ECU2_SERIAL_TERMINATOR  = 'CR';
        ECU2_SERIAL_FLOW_CONTROL = 'software';
        ECU2_SERIAL_TIMEOUT      = 0.5;
                
        NUM_PMTS = 4;
        
        ZOOM_VOLT_CONVERSION_FACTOR = 1023/5;
        MAX_GAIN = 510;
        MAX_SCAN_ALIGN = 255;
        
        thorSerialBugEnableWarkaround = true;
    end
    
    properties (SetAccess=private)
        lscInitSuccessful = false;
        lscFirmwareVersion;
        
        ecuInitSuccessful = false;
        ecuSoftwareVersion;
        ecuHardwareVersion;
        
        hasRotation = false;
    end
    
    properties (SetAccess=private, Dependent, SetObservable = true)
        rotationAngleAbsolute;
        isRotating;
        isMovingZ;
    end
    
    properties (SetAccess=private, SetObservable = true)
        pmtsStatus = struct('on',[],'gain',[],'tripped',[],'peltierOk',[]);
    end
    
    properties (SetAccess = private, Hidden)
        % Serial interface handles
        hLscSerial;
        hEcuSerial;
        
        ecuSerialAsyncReplyPending = false;
        ecuCommandQueue = {};
        ecuAsyncCallback;
        ecuLastAsyncCmd = '';
        ecuAsyncTimeoutTimer;
        
        zStepMult = 128.2051; % calculated when zStepSize is set
    end
    
    properties (SetObservable = true)
        zoomVolts;
        scanAlign = 0;
        
        flipperMirrorPosition = NaN;
        galvoResonantMirrorInPath = NaN;
        galvoGalvoMirrorInPath = NaN;
        
        ecuSerialVerbose = false;
        
        enableFastZStep = true; % enables the use of faster (but less accurate) z position command. The command is run several times to compensate for the accuracy issue
        fastZStepThresh = 30; % faster command will only be used for z steps less than or equal to fastZStepThresh. The faster Z step algorithm is blocking and has some overshoot at very large values (>200 um)
        zStepSize = 0.0078; % Z step size in nm. Older systems that do not have the 5:1 gear might be 39nm
    end
    
   
    %% LIFECYCLE
    methods

        function obj = BScope2(varargin)
            % PV args:
            % Optional:
            %   numDeviceDimensions: Number of dimensions for stage controller
            %   ecuComPort: COM port for ECU2 interface
            %   lscComPort: COM port for MCM5000 controller interface
            %   suppressInitWarning: Suppresses the warning if comports not provided
            ip = most.util.InputParser;
            ip.addOptional('numDeviceDimensions', 3);
            ip.addOptional('suppressInitWarning',false);
            ip.addOptional('ecuComPort',-1);
            ip.addOptional('lscComPort',-1);
            ip.addOptional('hasRotation',0);
            ip.parse(varargin{:});
            lscArgs = most.util.structPV2cellPV(ip.Results);
            
            obj = obj@dabs.interfaces.LinearStageController(lscArgs{:});
            
            if ip.Results.ecuComPort == -1
                if ~ip.Results.suppressInitWarning
                    warning OFF BACKTRACE
                    warning('BScope2: ECU2 COM port was not specified. Call initEcu2 with the COM port to init ECU2 interface.');
                    warning ON BACKTRACE
                end
            else
                obj.initEcu2('comPort', ip.Results.ecuComPort);
            end
            
            if ip.Results.lscComPort == -1
                if ~ip.Results.suppressInitWarning
                    warning OFF BACKTRACE
                    warning('BScope2: Stage controller COM port was not specified. Call initLsc with the COM port to init stage controller interface.');
                    warning ON BACKTRACE
                end
            else
                obj.initLsc('comPort', ip.Results.lscComPort, 'hasRotation', ip.Results.hasRotation);
            end
            
        end
        
        function initEcu2(obj, varargin)
            fprintf(1,'Initializing BScope2 ECU2 interface...\n');
            
            % validation for baudRate
            ip = most.util.InputParser;
            ip.addRequiredParam('comport',@(x)isscalar(x) && isnumeric(x));
            ip.addOptional('baudrate',obj.ECU2_SERIAL_BAUD_RATE); % (ngc 20140715 - FIXME: remove legacy tag and fix warning.  This validator is getting called with arguments that were never intended to be passed in.
            ip.parse(varargin{:});
            
            try
                obj.hEcuSerial = serial(sprintf('COM%d',ip.Results.comport));
                obj.hEcuSerial.BaudRate    = ip.Results.baudrate;
                obj.hEcuSerial.FlowControl = obj.ECU2_SERIAL_FLOW_CONTROL;
                obj.hEcuSerial.Terminator  = obj.ECU2_SERIAL_TERMINATOR;
                obj.hEcuSerial.Timeout =     obj.ECU2_SERIAL_TIMEOUT;
                
                obj.hEcuSerial.BytesAvailableFcnMode = 'terminator';
                obj.hEcuSerial.BytesAvailableFcn = @obj.ecuAsyncReplyAvailableFcn;
                
                fopen(obj.hEcuSerial);
                
                obj.ecuAsyncTimeoutTimer = timer('Name','BScope2 ECU2 Async Cmd Timout Timer');
                obj.ecuAsyncTimeoutTimer.ExecutionMode = 'singleShot';
                obj.ecuAsyncTimeoutTimer.StartDelay = obj.ECU2_SERIAL_TIMEOUT;
                obj.ecuAsyncTimeoutTimer.TimerFcn = @obj.ecuAsyncTimeoutFcn;
                
                obj.validateEcuVersion();
                obj.ecuInitSuccessful = true;
                
                obj.zoomVolts = 0;
                obj.scanAlign = 0;
                
                obj.updatePmtsStatus();
            catch ME
                fprintf(2,'Error during initialization of BScope2 interface.\nEnsure the ECU2 is powered on, the USB cable is connected and the right serial port is configured in the Machine Data File.\nDisabling BScope2 ECU2 interface.\nError report:\n%s\n',ME.message);
                if most.idioms.isValidObj(obj.hEcuSerial)
                    delete(obj.hEcuSerial);
                end
                obj.hEcuSerial = [];
                obj.ecuInitSuccessful = false;
            end
        end
        
        
        function initLsc(obj, varargin)
            % obj = LSCSerial(p1,v1,p2,v2,...)
            %
            % P-V options:
            % comPort: (REQUIRED) Integer specifying COM port of serial device
            % baudRate: (OPTIONAL) Integer etc.
            %
            % See constructor documentation for
            % dabs.interfaces.RS232DeviceBasic and
            % dabs.interfaces.LinearStageController for other P-V arguments.

            % The LinearStageController ignores unrecognized PVs
            
            fprintf(1,'Initializing BScope2 stage controller interface...\n');
            
            % validation for baudRate
            ip = most.util.InputParser;
            ip.addRequiredParam('comport',@(x)isscalar(x) && isnumeric(x));
            ip.addOptional('baudrate',obj.lscDefaultBaudRate,@(x)ismember(x,obj.lscAvailableBaudRates,'legacy')); % (ngc 20140715 - FIXME: remove legacy tag and fix warning.  This validator is getting called with arguments that were never intended to be passed in.
            ip.parse(varargin{:});
            comportAndBaudRatePV = most.util.structPV2cellPV(ip.Results);
            
            ip2 = most.util.InputParser;
            ip2.addOptional('hasRotation',0);
            ip2.parse(varargin{:});
            obj.hasRotation = ip2.Results.hasRotation;
            
            % add terminator
            comportAndBaudRatePV{end+1} = 'defaultTerminator';
            comportAndBaudRatePV{end+1} = 'CR';
            
            % for now, hardcode P-V args accepted by RS232. best way to
            % handle this unclear
            rs232OptionalArgs = {'skipTerminatorOnSend';'deviceErrorResp';...
                'deviceSimpleResp';'defaultTerminator';'defaultTimeout'};
            remainderPV = ip.Unmatched;
            remainderPV = most.util.restrictField(remainderPV,rs232OptionalArgs);
            remainderPV = most.util.structPV2cellPV(remainderPV);
            
            try
                obj.hLscSerial = dabs.interfaces.RS232DeviceBasic(comportAndBaudRatePV{:},remainderPV{:});
                obj.validateLscVersion();
                obj.lscInitSuccessful = true;
                fprintf('BScope2: Stage controller detected: FW version: %s\n',obj.lscFirmwareVersion);
                obj.reset(); %Resets the device, preparing it to receive remote commands
                
                %There is no way to query the current mirror position from the stage controller
                %Set the position so that we know what the mirror states are
                obj.flipperMirrorPosition = 'pmt';
                obj.galvoResonantMirrorInPath = 1;
                obj.galvoGalvoMirrorInPath = 0;
                
                obj.moveTimeout = 5;
            catch ME
                if most.idioms.isValidObj(obj.hLscSerial)
                    delete(obj.hLscSerial);
                end
                obj.hLscSerial = [];
                obj.lscInitSuccessful = false;
                fprintf(2,'Initialization of BScope2 stage controller failed.\nEnsure the stage controller is powered on, the USB cable is connected and the right serial port is configured in the Machine Data File.\nDisabling BScope2 stage controller interface.\nError report:\n%s\n',ME.message);
            end
            
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLscSerial);
            
            if most.idioms.isValidObj(obj.hEcuSerial)
                obj.setPmtsPower(zeros(1, obj.NUM_PMTS));
                obj.waitForCmdQueueToClear(1);
                delete(obj.hEcuSerial);
            end
            
            if most.idioms.isValidObj(obj.ecuAsyncTimeoutTimer)
                stop(obj.ecuAsyncTimeoutTimer);
                delete(obj.ecuAsyncTimeoutTimer);
            end
        end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods

        function tf = get.isMoving(obj)
            % alternatively could query status to see if a move cmd is in progress
            % '/#QR' response is either /0ReadyR or /0BusyR (# = axis)
            % /#QR returns busy even for manual control moving so result would be same
            tf = any(obj.velocityRaw ~= 0);
        end
        
        
        function tf = get.isMovingZ(obj)
            % alternatively could query status to see if a move cmd is in progress
            % '/#QR' response is either /0ReadyR or /0BusyR (# = axis)
            % /#QR returns busy even for manual control moving so result would be same
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/3?VR');
            z = str2num(resp(3:end-1));
            tf = z ~= 0;
        end

        
        % throws
        function v = get.positionAbsoluteRaw(obj)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/1?8R');
            if resp(end-1) == 'L'
                if resp(end-2) == 'U'
                    lim = 'Upper ';
                else
                    lim = 'Lower ';
                end
                
                fprintf(2, [lim 'limit of X axis reached. Use manual controls to exit limit region.\n']);
            end
            x = str2num(resp(3:end-1));
            
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/2?8R');
            if resp(end-1) == 'L'
                if resp(end-2) == 'U'
                    lim = 'Upper ';
                else
                    lim = 'Lower ';
                end
                
                fprintf(2, [lim 'limit of Y axis reached. Use manual controls to exit limit region.\n']);
            end
            y = str2num(resp(3:end-1));
            
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/3?8R');
            if resp(end-1) == 'L'
                if resp(end-2) == 'U'
                    lim = 'Upper ';
                else
                    lim = 'Lower ';
                end
                
                fprintf(2, [lim 'limit of Z axis reached. Use manual controls to exit limit region.\n']);
            end
            z = str2num(resp(3:end-1));
            
            % units are different from position request units and are different
            % for z axis so convert to microns here
            v = [x/2 y/2 z/10];
            assert(all(size(v) == [1 obj.numDeviceDimensions]), 'Error reading stage position.');
        end
        
        
        function v = get.velocityRaw(obj)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/1?VR');
            x = str2num(resp(3:end-1));
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/2?VR');
            y = str2num(resp(3:end-1));
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/3?VR');
            z = str2num(resp(3:end-1));
            
            v = [x y z];
            assert(all(size(v) == [1 obj.numDeviceDimensions]), 'Error reading stage velocity.');
        end
            
        function v = get.maxVelocityRaw(obj)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/1?2R');
            x = str2num(resp(3:end-1));
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/2?2R');
            y = str2num(resp(3:end-1));
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/3?2R');
            z = str2num(resp(3:end-1));
            
            v = [x y z];
            assert(all(size(v) == [1 obj.numDeviceDimensions]), 'Error reading max stage velocity.');
        end
        
        
        function set.flipperMirrorPosition(obj, pos)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            switch pos
                case 'camera'
                    resp = obj.hLscSerial.sendCommandReceiveStringReply('/1M0R');
                    assert(strcmp(resp, '/0M0okR'), ['Error while attempting to command flipper mirror position: ' resp]);
                case 'pmt'
                    resp = obj.hLscSerial.sendCommandReceiveStringReply('/1M1R');
                    assert(strcmp(resp, '/0M1okR'), ['Error while attempting to command flipper mirror position: ' resp]);
                otherwise
                    assert(false, 'Invalid position requested for flipper mirror.');
            end
            obj.flipperMirrorPosition = pos;
        end
        
        
        function set.galvoResonantMirrorInPath(obj, pos)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            posc = int2str(~logical(pos));
            resp = obj.hLscSerial.sendCommandReceiveStringReply(['/1MR' posc 'R']);
            assert(strcmp(resp, ['/0MR' posc 'okR']), ['Error while attempting to command RG mirror position: ' resp]);
            obj.galvoResonantMirrorInPath = pos;
        end
        
        
        function set.galvoGalvoMirrorInPath(obj, pos)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            posc = int2str(~logical(pos));
            resp = obj.hLscSerial.sendCommandReceiveStringReply(['/1MG' posc 'R']);
            assert(strcmp(resp, ['/0MG' posc 'okR']), ['Error while attempting to command GG mirror position: ' resp]);
            obj.galvoGalvoMirrorInPath = pos;
        end
        
        
        function set.zoomVolts(obj,val)
            assert(obj.ecuInitSuccessful, 'Cannot execute this command. ECU2 interface has not been initialized.');
            
            validateattributes(val,{'numeric'},{'scalar','nonnegative','<=',5});
            if val > 0
                zoomVal = round(val*obj.ZOOM_VOLT_CONVERSION_FACTOR);
                zoomString = sprintf('zoom=%d',zoomVal);
                obj.ecuWriteSerialCmdAsync(zoomString,@obj.doNothingFcn);
                obj.ecuWriteSerialCmdAsync('scan=1',@obj.doNothingFcn);
            else
                obj.ecuWriteSerialCmdAsync('scan=0',@obj.doNothingFcn);
            end
            obj.zoomVolts = val;
        end
        
        
        function set.scanAlign(obj,val)
            if obj.ecuInitSuccessful
                validateattributes(val,{'numeric'},{'scalar','nonnegative','integer','<=',obj.MAX_SCAN_ALIGN});
                scanAlignString = sprintf('scanalign=%d',val);
                obj.ecuWriteSerialCmdAsync(scanAlignString,@obj.doNothingFcn);
                obj.scanAlign = val;
            else
                fprintf(2, 'Cannot execute this command. ECU2 interface has not been initialized.\n');
            end
        end
        
        function r = get.rotationAngleAbsolute(obj)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            if obj.hasRotation
                resp = obj.hLscSerial.sendCommandReceiveStringReply('/4?8R');
                r = str2double(resp(3:end-1))/873;
                %resp = /0LLR when no rotation axis present
                assert(~isnan(r), 'Error reading stage rotation angle.');
            else
                r = 0;
            end
        end
        
        function tf = get.isRotating(obj)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/4?VR');
            resp = str2double(resp(3:end-1));
            assert(~isnan(resp), 'Error reading stage rotation angle.');
            tf = resp ~= 0;
        end
        
        function set.zStepSize(obj, v)
            obj.zStepSize = v;
            obj.zStepMult = 1/v;
        end
        
    end
        
    %% ABSTRACT METHOD IMPLEMENTATIONS (dabs.interfaces.LinearStageController)
    methods (Access=protected,Hidden)

        function moveStartHook(obj,absTargetPosn)
            % units for requesting move are different from those for querying
            % position so must do a conversion from microns here
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            p = obj.positionAbsoluteRaw;
            
            if p(1) ~= absTargetPosn(1)
                obj.hLscSerial.sendCommand(['/1A' int2str(absTargetPosn(1)*25.6) 'R']);
            end
            
            if p(2) ~= absTargetPosn(2)
                obj.hLscSerial.sendCommand(['/2A' int2str(absTargetPosn(2)*25.6) 'R']);
            end
            
            if p(3) ~= absTargetPosn(3)
                t = absTargetPosn(3) - p(3);
                ta = abs(t);
                
                if obj.enableFastZStep && ta <= obj.fastZStepThresh
                    % blocking fast move algorithm
                    m = 0;
                    while ta > 0.1 && m < 5
                        % determine move command direction
                        if t < 0
                            cmd = 'D';
                        else
                            cmd = 'P';
                        end
                        
                        % send move command
                        obj.hLscSerial.sendCommand(['/3' cmd int2str(ta*obj.zStepMult) 'R']);
                        m = m+1;
                        
                        % wait for move to complete
                        pause(0.2);
                        while obj.isMovingZ()
                            pause(0.05);
                        end
                        
                        % determine if another move command is needed
                        p = obj.positionAbsoluteRaw;
                        t = absTargetPosn(3) - p(3);
                        ta = abs(t);
                    end
                else
                    % start normal slow non blocking move
                    obj.hLscSerial.sendCommand(['/3A' int2str(absTargetPosn(3)*25.6) 'R']);
                end
            end
        end
        
        function interruptMoveHook(obj)
            obj.hLscSerial.sendCommandReceiveStringReply('/1TR');
            obj.hLscSerial.sendCommandReceiveStringReply('/2TR');
            obj.hLscSerial.sendCommandReceiveStringReply('/3TR');
            obj.hLscSerial.sendCommandReceiveStringReply('/4TR');
        end
        
        function resetHook(obj)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            obj.hLscSerial.flushInputBuffer();
            
            obj.hLscSerial.sendCommandReceiveStringReply('/1TR');
            obj.hLscSerial.sendCommandReceiveStringReply('/2TR');
            obj.hLscSerial.sendCommandReceiveStringReply('/3TR');
            obj.hLscSerial.sendCommandReceiveStringReply('/4TR');
            
            obj.validateLscVersion();
        end
        
        
        function recoverHook(obj)
            numTries = 15;
            for i = 1:numTries
                try
                    obj.resetHook();
                catch ME
                    if i < numTries
                        continue;
                    else
                        ME.rethrow();
                    end
                end
                break;
            end
        end
        
    end
    
    
    %% USER METHODS
    methods
        
        function setPmtPower(obj, pmtNum, val)
            assert(obj.ecuInitSuccessful, 'Cannot execute this command. ECU2 interface has not been initialized.');
            
            validateattributes(val,{'logical','numeric'},{'vector','numel',1});
            validateattributes(pmtNum,{'numeric'},{'vector','numel',1,'integer','nonnegative','<=',obj.NUM_PMTS});
            
            cmd = sprintf('pmt%d=%d',pmtNum,logical(val));
            obj.ecuWriteSerialCmdAsync(cmd,@obj.doNothingFcn);
        end
        
        
        function setPmtsPower(obj, val)
            assert(obj.ecuInitSuccessful, 'Cannot execute this command. ECU2 interface has not been initialized.');
            
            validateattributes(val,{'logical','numeric'},{'vector','numel',obj.NUM_PMTS});
            
            for i = 1:obj.NUM_PMTS
                obj.setPmtPower(i, val(i))
            end
        end
        
        
        function setPmtGain(obj, pmtNum, val)
            assert(obj.ecuInitSuccessful, 'Cannot execute this command. ECU2 interface has not been initialized.');
            
            validateattributes(val,{'numeric'},{'vector','numel',1,'integer','nonnegative','<=',obj.MAX_GAIN});
            validateattributes(pmtNum,{'numeric'},{'vector','numel',1,'integer','nonnegative','<=',obj.NUM_PMTS});
            
            cmd = sprintf('pmt%dgain=%d',pmtNum,val);
            obj.ecuWriteSerialCmdAsync(cmd,@obj.doNothingFcn);
        end
        
        
        function setPmtsGains(obj, val)
            assert(obj.ecuInitSuccessful, 'Cannot execute this command. ECU2 interface has not been initialized.');
            
            validateattributes(val,{'logical','numeric'},{'vector','numel',obj.NUM_PMTS});
            
            for i = 1:obj.NUM_PMTS
                obj.setPmtGain(i, val(i))
            end
        end
        
        
        function updatePmtsStatus(obj)
            assert(obj.ecuInitSuccessful, 'Cannot execute this command. ECU2 interface has not been initialized.');
            
            for pmtNum = 1:obj.NUM_PMTS
                cmd = sprintf('pmt%d?',pmtNum);
                obj.ecuWriteSerialCmdAsync(cmd,@obj.processPmtStatus)
            end
        end
        
        function tf = startRotation(obj, val)
            assert(obj.lscInitSuccessful, 'Cannot execute this command. Stage controller interface has not been initialized.');
            
            if ~obj.isRotating
                obj.hLscSerial.sendCommand(['/4A' int2str(val*23728.1) 'R']);
                tf = true;
            else
                warnst = warning('off','backtrace');
                warning('Stage is currently executing a previous rotation command. New command is ignored.');
                warning(warnst);
                tf = false;
            end
        end
        
        function tf = completeRotation(obj, val)
            tf = obj.startRotation(val);
            if tf
                TIGHT_LOOP_PAUSE_INTERVAL = 0.01;
                tstart = tic;

                while obj.isRotating
                    if toc(tstart) > obj.moveTimeout
                        warnst = warning('off','backtrace');
                        warning('Blocking rotate timed out.');
                        warning(warnst);
                        tf = false;
                        break;
                    end
                    pause(TIGHT_LOOP_PAUSE_INTERVAL);
                end
            end
        end
        
    end
    
    
    %% HIDDEN METHODS
    methods (Hidden)
        
        function ecuWriteSerialCmdAsync(obj,cmd,callback)
            assert(isa(cmd,'char'));
            assert(isa(callback,'function_handle'));
            if ~obj.ecuSerialAsyncReplyPending;
                obj.ecuFlushInputBuffer();
                obj.ecuAsyncCallback = callback;
                obj.ecuLastAsyncCmd = cmd;
                
                if obj.ecuSerialVerbose
                    fprintf(1,['ECU2 Cmd: ' cmd '\n']);
                end
                
                if obj.thorSerialBugEnableWarkaround
                    obj.ecuWriteSerialCmdBytewise(cmd);
                else
                    fprintf(obj.hEcuSerial,cmd,'async');
                end
                
                obj.ecuSerialAsyncReplyPending = true;
                stop(obj.ecuAsyncTimeoutTimer);
                start(obj.ecuAsyncTimeoutTimer);
            else
                obj.ecuCommandQueue{end+1}  = {cmd,callback};
            end
        end
        
        
        function answerLines = ecuWriteSerialCmd(obj,cmd,numAnswerLines)
            if nargin < 3 || isempty(numAnswerLines)
                numAnswerLines = 1;
            end
            
            assert(~obj.ecuSerialAsyncReplyPending);
            
            obj.ecuFlushInputBuffer();
            
            if obj.thorSerialBugEnableWarkaround
                obj.ecuWriteSerialCmdBytewise(cmd);
            else
                fprintf(obj.hEcuSerial,cmd);
            end
            
            if nargout
                answerLines = {};
                for i = 1:numAnswerLines
                    answerLines{i} = fgetl(obj.hEcuSerial); %#ok<AGROW>
                end
            end
        end
        
        
        function ecuFlushInputBuffer(obj)
            if obj.hEcuSerial.BytesAvailable
                fread(obj.hEcuSerial,obj.hEcuSerial.BytesAvailable);
            end
        end
        
        function waitForCmdQueueToClear(obj, timeout)
            st = tic();
            while (numel(obj.ecuCommandQueue) > 0) && (toc(st) < timeout)
                pause(0.1);
            end
        end

    end
    
    
    %% PRIVATE METHODS
    methods (Access=protected,Hidden)
        
        function validateLscVersion(obj)
            resp = obj.hLscSerial.sendCommandReceiveStringReply('/1FR');
            obj.lscFirmwareVersion = resp(3:end);
            assert(any(strcmp(obj.lscFirmwareVersion, obj.lscSupportedFirmwareVersions)), ...
                ['Initialization of BScope2 stage controller failed. Unsupported firmware version ''' obj.lscFirmwareVersion '''.']);
        end
        
        
        function validateEcuVersion(obj)
            try
                answerLines = obj.ecuWriteSerialCmd('version?',3);
                answerLines(1) = []; % remove mirrored command;
                answer = strjoin(answerLines);
            catch ME
                error('BScope2: Detecting ECU2 version failed with error: %s\n',ME.message);
            end
            
            foundIdentifier = ~isempty(strfind(answer,'ECU Version'));
            softwareVersionECU_ = obj.parseAnswer(answer,'SW:');
            hardwareVersionECU_ = obj.parseAnswer(answer,'HW:');
            
            swSupported = isSupported(softwareVersionECU_,obj.ECU2_SUPPORTED_SOFTWARE_VERSIONS);
            hwSupported = isSupported(hardwareVersionECU_,obj.ECU2_SUPPORTED_HARDWARE_VERSIONS);

            detectedTf = foundIdentifier && swSupported && hwSupported;
            
            assert(detectedTf,'BScope2: Detection of ECU2 failed. Serial response: %HW version: %s',answer);
            
            obj.ecuSoftwareVersion = softwareVersionECU_;
            obj.ecuHardwareVersion = hardwareVersionECU_;
            
            fprintf('BScope2: ECU2 detected: HW version: %s, SW version: %s\n',obj.ecuSoftwareVersion,obj.ecuHardwareVersion);
            
            function supportedTf = isSupported(version,supportedVersions)
                % partially matches a software/hardware version in a cell array of strings
                % example:
                % version = '70-008-1.1'
                % supportedVersions = {'70-008-1'}
                %
                % output: supportedTf = true
                
                supportedTf = false;
                for i = 1:length(supportedVersions)
                    supportedVersion = supportedVersions{i};
                    partialMatchIndex = strfind(version,supportedVersion);
                    partialMatch = ~isempty(partialMatchIndex) && partialMatchIndex == 1;
                    supportedTf = supportedTf || partialMatch;
                end
            end
        end
        
        %Return value of best (finest) resolution supported by device, in
        %positionDeviceUnits, as a scalar or array of [1 numDeviceDimensions]
        function val = getResolutionBestHook(obj)
            val = [.5 .5 .1];
        end
        
        function ecuAsyncReplyAvailableFcn(obj,~,~)
            if obj.ecuSerialAsyncReplyPending
                stop(obj.ecuAsyncTimeoutTimer);
                reply = fgetl(obj.hEcuSerial);
                obj.ecuSerialAsyncReplyPending = false;
                obj.ecuLastAsyncCmd = '';
                
                if obj.ecuSerialVerbose
                    fprintf(1,['ECU2 Rep: ' reply '\n']);
                end
                
                % process answer
                if ~isempty(obj.ecuAsyncCallback)
                    obj.ecuAsyncCallback(reply);
                    obj.ecuAsyncCallback = [];
                end
                
                % send next command in commandQueue
                if ~isempty(obj.ecuCommandQueue)
                    nextCommand = obj.ecuCommandQueue{1};
                    obj.ecuCommandQueue(1) = [];
                    obj.ecuWriteSerialCmdAsync(nextCommand{:});
                end
            end
        end
        
        
        function ecuAsyncTimeoutFcn(obj,~,~)
            stop(obj.ecuAsyncTimeoutTimer);
            most.idioms.warn(['Timeout occurred while waiting for reply to ''' obj.ecuLastAsyncCmd ''' cmd from Thorlabs ECU2']);
            obj.ecuSerialAsyncReplyPending = false;
            obj.ecuLastAsyncCmd = '';
            pause(obj.ECU2_SERIAL_TIMEOUT);
            obj.ecuFlushInputBuffer();
            
            % send next command in commandQueue
            if ~isempty(obj.ecuCommandQueue)
                nextCommand = obj.ecuCommandQueue{1};
                obj.ecuCommandQueue(1) = [];
                obj.ecuWriteSerialCmdAsync(nextCommand{:});
            end
        end
        
        
        function ecuWriteSerialCmdBytewise(obj,cmd)
            % workaround for apparent bug in ThorECU2: when sending command
            % as one package, the command is mirrored incorrectly
            % send command bytewise instead
            arrayfun(@(cmdChar)fprintf(obj.hEcuSerial,'%s',cmdChar),cmd);
            fprintf(obj.hEcuSerial,'');
        end
        
        
        function val = parseAnswer(~,answer,key)
            % parses the value for a specific key out of the ThorECU answer string
            % Example:
            % answer = 'ECU Version     HW: 41-0027-006     SW: 70-008-1.1 Motherboard Revision: 0'
            % key = 'HW:'
            %
            % output: val = '41-0027-006'
            key = regexptranslate('escape',key);
            val = regexpi(answer,['(?<=' key ')\s*([^\s]+)'],'match','once');
            if ~isempty(val)
                val = regexprep(val,'^\s*',''); % remove leading spaces
                val = regexprep(val,',$',''); % remove comma at end of string
            end
        end
        
        
        function processPmtStatus(obj,reply)
            % format of reply:
            % pmt1?    Off, Gain:    0   PMT: OK   Peltier: OK
            pmtNumChar = regexp(reply,'(?<=pmt)[0-9]+(?=\?)','match','once');
            if ~isempty(pmtNumChar)
                pmtNum = str2double(pmtNumChar);
                
                %create and modify temporary copy so that event is only fired once
                tmp = obj.pmtsStatus;
                
                tmp.on(pmtNum)        = strcmpi(obj.parseAnswer(reply,sprintf('pmt%d?',pmtNum)),'On');
                tmp.gain(pmtNum)      = str2double(obj.parseAnswer(reply,'Gain:'));
                tmp.tripped(pmtNum)   = ~strcmpi(obj.parseAnswer(reply,'PMT:'),'OK');
                tmp.peltierOk(pmtNum) = strcmpi(obj.parseAnswer(reply,'Peltier:'),'OK');
                
                obj.pmtsStatus = tmp;
            else
                fprintf(2,'BScope2: Cannot process pmt status ''%s''\n',reply);
            end
        end
        
        
        function doNothingFcn(~,varargin)
            % Do nothing
        end
        
    end
    
end



%--------------------------------------------------------------------------%
% BScope2.m                                                                %
% Copyright © 2015 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 5 is licensed under the Apache License, Version 2.0            %
% (the "License"); you may not use any files contained within the          %
% ScanImage 5 release  except in compliance with the License.              %
% You may obtain a copy of the License at                                  %
% http://www.apache.org/licenses/LICENSE-2.0                               %
%                                                                          %
% Unless required by applicable law or agreed to in writing, software      %
% distributed under the License is distributed on an "AS IS" BASIS,        %
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. %
% See the License for the specific language governing permissions and      %
% limitations under the License.                                           %
%--------------------------------------------------------------------------%
