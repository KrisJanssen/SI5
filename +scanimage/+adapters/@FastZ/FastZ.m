classdef FastZ < most.MachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'FastZ';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %% PUBLIC PROPERTIES
    properties (SetObservable)
        acqState = 'idle'; %One of {'focus' 'grab' 'loop' 'idle'}
        acqNumFrames;
        % acqBeamLengthConstants;
        stackNumSlices;
        stackZStepSize;
        stackStartCentered;
        scanFrameRate;
        acqTriggerTypeExternal;
        resonantScannerFreq;
        bidirectionalAcq;

        %internal set flag (What is this used for??)
        internalSetFlag = false;
        
        extFrameClockTerminal;
        fastZAcquisitionDelay; %Acquisition delay, in seconds, of fastZScanner. Value is exactly 1/2 the fastZSettlingTime.
        fastZAvailable;
        
        hFastZ; %Handle to FastZ hardware, may be a LSC object or a PI motion controller
        hFastZAO; %Handle to DAQmx AO Task used for FastZ sweep/step control
        
        positionAbsolute; % used by parent object to get hFastZ.positionAbsolute
        
        fastZAOOutputRate;      % Automatically set to maximum AO output rate supported by DAQ device
        fastZRequireAO = false;
        fastZAODataNormalized; %Array of output data for fastZAO Task, corresponding to one volume period
        fastZAODataSlope; %Slope of fastZAO data during command ramp
        fastZHomePosition; %Cache of the fastZ controller's position at start of acquisition mode, which should be restored at conclusion of acquisition mode
        fastZNextTrigSignal; %Flag signaling that advancing next trigger occurred during fastZ volume imaging -- file & file counter should be updated at start of next volume
        fastZBeamDataBuf; %Buffer of fastZ beam data, maintained if fastZAllowLiveBeamAdjust=true
        
        fastZBeamPowersCache; %Cache of beamPowers data, maintained if fastZAllowLiveBeamAdjust=true
        fastZBeamWriteOffset; %Store the offset to next write to FastZ Beam AO Task
        fastZBeamNumBufferedVolumes = 1; %Number of volumes to buffer. Any changes to beam params will take places with latency of (fastZBeamNumBufferedVolumes-1) volumes
        %fastZAORange; %2 element array containining [min max] voltage values allowed for FastZ AO control
        
        %Fast Z
        fastZEnable = false;
        fastZImageType = 'XY-Z'; %One of {'XY-Z' 'XZ' 'XZ-Y'}
        fastZScanType = 'sawtooth'; %One of {'step' 'sawtooth'}
        fastZSettlingTime = 0; %Time, in seconds, for axial position/ramp to settle. If fastZScanType='step', this value may be an array containing settling-time values to use for each step -- on per element in fastZScanRangeSpec.
        fastZNumVolumes = 1; %Number of 'volumes' to collect, i.e. number of times to repeat the fastZ scan. fastZNumVolumes=1 implies 'fast stack' operation.
        fastZDiscardFlybackFrames = false; %Logical indicating whether to discard frames during fastZ scanner flyback
        fastZUseAOControl = true; %Logical indicating whether to use AO control of fastZ hardware during FastZ operations
        fastZFramePeriodAdjustment = -100; %Time, in us, to deduct from the nominal frame period, when determining fastZ sawtooth period used for volume imaging
        fastZAllowLiveBeamAdjust = false; %Logical indicating whether to allow live adjustment of beamPowers during fastZ imaging.
        fastZPeriod; %Time specification in seconds. Co-varies with stackNumSlices/stackZStepSize. For fastZScanType='sawtooth', specifies period of scan in fastZ dimension. For fastZScanType='step', specifieds time or times (if supplied as vector) to spend at each step (i.e. value per element in fastZScanRangeSpec).;
        fastZFillFraction; %Fraction of frames in acquisition stream during fastZ imaging
        fastZVolumesDone = 0; %Number of volume sweeps completed, during a fastZ scan
        fastZActive = false; %true if fastZ scanning is ongoing
    end
    
    properties (Hidden, Dependent)
        fastZNumDiscardFrames; %Number of discarded frames for each period
        scanFramePeriod;
        
        fastZSecondMotor;
    end
    
    %% INTERNAL PROPS
    properties (Hidden,SetAccess=protected)
        hModel;
        hDaqDevice;
        daqDevBusType;
        daqDevPxiChassis;
        daqDevPxiSlot;
    end
    
    %% LIFECYCLE
    methods
        function obj = FastZ(hModel)
            if nargin < 1 || isempty(hModel)
                hModel = [];
            end
            obj.hModel = hModel;
            
            obj.ziniPrepareFastZ();
            obj.zprvGoPark();
        end
        
        function delete(obj)
            if ~isempty(obj.hFastZAO)
                obj.hFastZAO.stop();
                delete(obj.hFastZAO);
                clear obj.hFastZAO;
            end            
        end
    end
    
    %% HIDDEN METHODS (FastZ Operations)
    methods (Hidden)
        function zprvMDFVerify(obj,mdfVarName,validAttribArgs,assertFcn)
            val = obj.mdfData.(mdfVarName);
            try
                if ~isempty(validAttribArgs)
                    validateattributes(val,validAttribArgs{:});
                end
                if ~isempty(assertFcn)
                    assert(assertFcn(val));
                end
            catch ME
                error('SI5:MDFVerify','Invalid value for MachineDataFile variable ''%s''.',mdfVarName);
            end
        end
        
        function zprvAssertIdle(obj,propName)
            assertion = obj.internalSetFlag || strcmpi(obj.acqState,'idle');
            try
                if nargin == 2
                    assert(assertion,'The property ''%s'' can only be set when in idle state',propName);
                else
                    assert(assertion,'The specified property can only be set when in idle state');
                end
            catch ME
                ME.throwAsCaller();
            end
        end
        
        function zprvAssertFocusOrIdle(obj,propName)
            assertion = obj.internalSetFlag || ismember(obj.acqState,{'idle' 'focus'});
            try
                if nargin == 2
                    assert(assertion,'The property ''%s'' can only be set when focusing or idle',propName);
                else
                    assert(assertion,'The specified property can only be set when focusing or idle');
                end
            catch ME
                ME.throwAsCaller();
            end
        end
        
        function zprvAssertNoAcq(obj,propName)
            assertion = obj.internalSetFlag || ismember(obj.acqState,{'idle' 'loop_wait'});
            try
                if nargin == 2
                    assert(assertion,'The property ''%s'' can only be set when in idle state',propName);
                else
                    assert(assertion,'The specified property can only be set when in idle state');
                end
            catch ME
                ME.throwAsCaller();
            end
        end
        
        function zprvResetHome(obj)
            %Reset fastZ positions
            obj.fastZHomePosition = [];
        end
        
        function zprvGoPark(obj)
            if obj.fastZAvailable
                disp('Moving Fast Z Stage to 0.0...');
                if obj.fastZSecondMotor
                    obj.hFastZ.moveCompleteAbsolute([nan nan 0.0]);
                else
                    obj.hFastZ.moveCompleteAbsolute([0.0 nan nan]);                    
                end
            end
        end
        
        function zprvGoHome(obj)
            %Go to home fastZ position, as applicable
            if ~isempty(obj.fastZHomePosition) && obj.fastZAvailable
                if obj.fastZSecondMotor
                    obj.hFastZ.moveCompleteAbsolute([nan nan obj.fastZHomePosition]);
                else
                    obj.hFastZ.moveCompleteAbsolute([obj.fastZHomePosition nan nan]);
                end
            end
        end
        
        function zprvOverrideableFunction(obj,fcnName,varargin)
            if isfield(obj.userFunctionsOverriddenFcns2UserFcns,fcnName)
                % function is overridden
                userFcn = obj.userFunctionsOverriddenFcns2UserFcns.(fcnName);
                feval(userFcn,obj,varargin{:});
            else
                feval(fcnName,obj,varargin{:});
            end
        end
        
        %         function voltage = zprvFastZPosn2Voltage(obj,posn)
        %
        %             %TODO: Handle PI device 'generality' (logic now specific to SystemParameterBasicProperties devices, e.g. E-516 & E-816) -- either via adaptor class, or via added MotionController smarts
        %             voltage = (posn / obj.hFastZ.hStage.kSen) + obj.hFastZ.hStage.oSen;
        %
        %             %Ensure voltage fits
        %             voltage = min(max(voltage,obj.fastZAORange(1)),obj.fastZAORange(2));
        %         end
        
        function startPosn = zprvFastZUpdateAOData(obj,startPosn)
            % Updates AO data on device buffer, after shifting 'normalized' data to volume position
            
            if ~obj.fastZUseAOControl
                return;
            end
            
            %Shift voltage range to start position
            %TODO: Handle PI device 'generality' (logic now specific to SystemParameterBasicProperties devices, e.g. E-516 & E-816) -- either via adaptor class, or via added MotionController smarts
            if nargin < 2 || isempty(startPosn)
                %The FastZ axis is (1) when configured as FastZ only. The
                %FastZ axis is (end) when configured as usesecondmotor.
                if obj.fastZSecondMotor
                    startPosn = obj.hFastZ.positionAbsolute(end); %Should this be (1) and not 'end'?
                else
                    startPosn = obj.hFastZ.positionAbsolute(1); %Should this be (1) and not 'end'?
                end
                %startPosn = obj.fastZPosnGet(); %Use current position, read from fastZ controller, as the start position
            end
            
            %Shift start position so starting axial position is located at center of first slice in fast-stack
            startPosn = startPosn - (obj.stackZStepSize)/2;
            
            %Shift start position so starting axial position is located at center of fast stack
            if obj.stackStartCentered
                startPosn = startPosn - ((obj.stackNumSlices-1) * obj.stackZStepSize)/2;
            end
            
            %Convert to voltage data
            startVoltage = obj.hFastZ.analogCmdPosn2Voltage(startPosn);
            fastZAOData = obj.fastZAODataNormalized + startVoltage;
            
            %Detect if command is outside allowable voltage range
            if max(fastZAOData(:)) > obj.hFastZAO.channels(1).get('max')
                maxClamp =  obj.hFastZAO.channels(1).max;
                fastZAOData(fastZAOData > maxClamp) = maxClamp;
                fprintf(2,'WARNING: Computed FastZ AO data exceeds maximum voltage of AO channel (%g). Full range of specified scan will not be achieved.\n',maxClamp);
            end
            
            if min(fastZAOData(:)) < obj.hFastZAO.channels(1).get('min')
                minClamp =  obj.hFastZAO.channels(1).min;
                fastZAOData(fastZAOData < minClamp) = minClamp;
                fprintf(2,'WARNING: Computed FastZ AO data falls below minimum voltage of AO channel (%g). Full range of specified scan will not be achieved.\n',minClamp);
            end
            
            %Shift voltage data to account for acquisition delay
            shiftVoltage = obj.fastZAcquisitionDelay * obj.fastZAODataSlope;
            fastZAOData = fastZAOData + shiftVoltage;
            
            %Update AO Buffer
            obj.hFastZAO.control('DAQmx_Val_Task_Unreserve'); %Flush any previous data in the buffer
            obj.hFastZAO.writeAnalogData(fastZAOData);
            obj.hFastZAO.cfgSampClkTiming(obj.fastZAOOutputRate, 'DAQmx_Val_FiniteSamps', obj.hFastZAO.get('bufOutputBufSize')); %Buffer length equals length of acquisition...no need to repeat
            obj.hFastZAO.set('startTrigRetriggerable',true);            
            obj.hFastZAO.start();
        end
        
        function zprvFastZUpdateAODataNormalized(obj)
            % Updates pre-computed buffer of 'normalized' AO data for FastZ operation
            % 'Normalized' data is properly scaled, but needs to be shifted to the stack starting position
            
            if ~obj.fastZAvailable || ~obj.fastZEnable || ~obj.fastZUseAOControl || isnan(obj.scanFramePeriod)
                obj.fastZAODataNormalized = [];
                return;
            end
            
            %Determine voltage range
            %Slice centers span (stackNumSlices - 1) * stackZStepSize, as
            %with a normal (slow) stack; the total span is larger, to cover
            %the first and last half-frames of the first and last slices,
            %respectively
            startVoltage = 0;
            endVoltage = obj.hFastZ.analogCmdPosn2Voltage(obj.stackNumSlices * obj.stackZStepSize);
            
            %Update fastZAODataNormalized property
            switch obj.fastZImageType
                case 'XY-Z'
                    znstFastZUpdateXYZ();
                case 'XZ'
                    znstFastZUpdateXZ();
                case 'XZ-Y'
                    if obj.stackNumSlices == 1
                        znstFastZUpdateXZ(); %Equivalent to XZ
                    else
                        znstFastZUpdateXZY();
                    end
                otherwise
                    assert(false);
            end
            
            return;
            
            function znstFastZUpdateXYZ()
                
                switch obj.fastZScanType
                    case 'sawtooth'
                        
                        numFramesImaged = obj.stackNumSlices * obj.acqNumFrames;
                        numFramesTotal = numFramesImaged + obj.fastZNumDiscardFrames;
                        obj.fastZFillFraction = (obj.stackNumSlices * obj.acqNumFrames) / numFramesTotal;
                        obj.fastZPeriod = numFramesTotal * (1/obj.scanFrameRate) + (numFramesTotal * obj.fastZFramePeriodAdjustment * 1e-6);
                        
                        outputRate = obj.fastZAOOutputRate;
                        
                        if obj.fastZDiscardFlybackFrames && obj.fastZNumDiscardFrames > 0
                            %Flyback/settling will occur during the discarded frame(s) at end of each stack frame set
                            
                            %TODO: Deal with negative ramp case
                            %TODO: Detect excessive memory use up front and prevent -- i.e. by warning and disabling FastZ mode
                            
                            totalNumSamples = ceil(obj.fastZPeriod * outputRate);
                            %rampNumSamples = round(((1/obj.scanFrameRate) * numFramesImaged + numFramesImaged * obj.fastZFramePeriodAdjustment * 1e-6) * obj.fastZAOOutputRate); %VI061112A: Arguably should be doing this instead
                            rampNumSamples = round((1/obj.scanFrameRate) * numFramesImaged * outputRate); %VVV061112A: Arguably we should should apply the fastZFramePeriodAdjustment for each frame in determining the length of ramp, as would be done by commented line above. Right now, all accumulated slop is shaved off the flyback time.
                            assert(rampNumSamples > 0);
                            settlingNumSamples = round(obj.fastZSettlingTime * outputRate);
                            
                            flybackNumSamples = totalNumSamples - (rampNumSamples + settlingNumSamples) - 1;
                            
                            rampData = linspace(startVoltage,endVoltage,rampNumSamples);
                            rampSlope = (endVoltage-startVoltage)/(rampNumSamples-1);
                            
                            settlingStartVoltage = startVoltage - rampSlope * settlingNumSamples;
                            
                            flybackData = linspace(endVoltage,settlingStartVoltage,flybackNumSamples+1);
                            flybackData(1) = [];
                            
                            settlingData = linspace(settlingStartVoltage,startVoltage,settlingNumSamples+1);
                            
                            obj.fastZAODataNormalized = [rampData flybackData settlingData]';
                        else
                            %Flyback/settling will occur at start of first frame in each stack frame set
                            %Command signal is simply naive...no shaped flyback or settling period
                            
                            rampNumSamples = outputRate * obj.fastZPeriod;
                            obj.fastZAODataNormalized = linspace(startVoltage,endVoltage,rampNumSamples)';
                            
                        end
                        
                        obj.fastZAODataSlope = (endVoltage-startVoltage)/(rampNumSamples/outputRate);
                        
                    case 'step'
                        %TODO
                        
                end
            end
            
            function znstFastZUpdateXZ()
                %TODO
            end
            
            function znstFastZUpdateXZY()
                %TODO
            end
            
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function val = get.fastZSecondMotor(obj)
            val = strcmpi(obj.mdfData.fastZControllerType,'useMotor2');
        end        
        
        function val = get.positionAbsolute(obj)
            val = obj.hFastZ.positionAbsolute;
        end
        
        function val = get.fastZAvailable(obj)
            val = obj.fastZAvailable;
        end
        
        function val = get.fastZActive(obj)
            val = ~ismember(obj.acqState,{'idle' 'focus'}) && obj.fastZEnable && obj.stackNumSlices > 1;
        end
        
        function val = get.fastZAcquisitionDelay(obj)
            val = obj.fastZSettlingTime / 2;
        end
        
        function set.fastZNumDiscardFrames(obj,val)
            %Do nothing as value is derived.
        end
        
        function val = get.fastZNumDiscardFrames(obj)
            %Number of discarded frames per-volume for XY-Z, XZ-Y cases and per-frame for XZ case
            
            if obj.fastZDiscardFlybackFrames
                %TODO: Tighten up these computations a bit to deal with edge cases
                %TODO: Could account for maximum slew rate as well, at least when 'velocity' property is available
                
                switch obj.fastZImageType
                    case 'XY-Z'
                        if obj.fastZNumVolumes == 1
                            val = 0;
                            return;
                        end
                    case 'XZ'
                        if obj.acqNumFrames == 1
                            val = 0;
                            return;
                        end
                    case 'XZ-Y'
                        if obj.stackNumSlices == 1 || obj.fastZNumVolumes == 1
                            val = 0;
                            return;
                        end
                end
                
                settlingNumSamples = round(obj.fastZAOOutputRate * obj.fastZSettlingTime);
                frameNumSamples = obj.fastZAOOutputRate * obj.scanFramePeriod;
                
                val = ceil(settlingNumSamples/frameNumSamples);
            else
                val = 0;
            end
        end
        
        function set.stackNumSlices(obj,val)
            obj.stackNumSlices = val;
        end
        
        function set.fastZEnable(obj,val)
            if ~obj.fastZAvailable
                val = false;
            end
            
            if isinf(obj.acqNumFrames)
                obj.modelWarn('Cannot enable FastZ imaging when acqNumFrames=Inf');
                val = false;
            end
            
            obj.fastZEnable = val;
            
            %Side effects
            if obj.fastZEnable
                obj.acqNumFrames = 1; %This will call zprvFastZUpdateAODataNormalized()
            else
                obj.stackNumSlices = obj.stackNumSlices; %Allows stack start/end point constraints to be re-applied, if applicable
            end
            
            %obj.acqBeamLengthConstants = []; %Force recompute on next use
            obj.zprvFastZUpdateAODataNormalized();
        end
        
        function set.fastZImageType(obj,val)
            %For now - force property value to 'xy-z'. The 'xz' and 'xz-y' modes are not supported as of SI 4.1.
            if ~strcmpi(val,'XY-Z')
                fprintf(2,'WARNING: Only ''XY-Z'' mode supported at this time. The ''XZ'' and ''XZ-Y'' modes may be supported in future versions.\n');
                val = 'XY-Z';
            end
            
            obj.fastZImageType = val;
            
            %Side effects
            obj.zprvFastZUpdateAODataNormalized();
        end
        
        function set.fastZScanType(obj,val)
            %For now - force property value to 'sawtooth'. The 'step' mode not supported as of SI 4.1.
            if ~strcmpi(val,'sawtooth')
                fprintf(2,'WARNING: FastZ Scan Type ''step'' not supported at this time. Forcing value to ''sawtooth''.\n');
                val = 'sawtooth';
            end
            
            obj.fastZScanType = val;
            
            %Side effects
            obj.zprvFastZUpdateAODataNormalized();
        end
        
        %         function set.fastZScanStartPosition(obj,val)
        %             val = obj.validatePropArg('fastZScanStartPosition',val);
        %             obj.zprvFastZUpdateAOData();
        %         end
        %
        %         function set.fastZScanStartPositionCentered(obj,val)
        %             val = obj.validatePropArg('fastZScanStartPositionCentered',val);
        %             obj.zprvFastZUpdateAOData();
        %         end
        %
        %         function set.fastZScanRangeSpec(obj,val)
        %             val = obj.validatePropArg('fastZScanRangeSpec',val);
        %             obj.zprvFastZUpdateAOData();
        %         end
        
        function set.fastZAcquisitionDelay(obj,val)
            obj.zprvAssertIdle('fastZAcquisitionDelay');
            obj.fastZSettlingTime = 2 * val;
        end
        
        function set.fastZAllowLiveBeamAdjust(obj,val)
            obj.zprvAssertIdle('fastZAllowLiveBeamAdjust');
            if val
                fprintf(2,'WARNING: FastZ Allow Live Beam Adjust beature not supported at this time. Forcing value to false.\n');
                val = false;
            end
            
            obj.fastZAllowLiveBeamAdjust = val;
        end
        
        function set.fastZSettlingTime(obj,val)
            obj.zprvAssertIdle('fastZSettlingTime');
            obj.fastZSettlingTime = val;
            
            %Allow 'live' adjustment of fastZ settling time when effectively in Focus mode
            if obj.fastZEnable &&  obj.fastZUseAOControl && obj.stackNumSlices > 1 && ~obj.hModel.loggingEnable && ~obj.acqTriggerTypeExternal && strcmpi(obj.acqState,'grab')
                
                %                 %The simplest approach!
                %                 obj.abort();
                %                 obj.startGrab();
                
                %Stop and restart scanning
                obj.hAcqTasks.abort();
                obj.hLSM.pause();
                
                %Compute new FastZ AO data
                obj.zprvFastZUpdateAODataNormalized();
                
                %fastZBeamEnable = ismember(obj.hBeams,obj.hAcqTasks);
                fastZBeamRewrite = obj.beamNumBeams > 0 && obj.beamPzAdjust;
                
                if ~isempty(obj.fastZHomePosition)
                    if obj.fastZSecondMotor
                        obj.hFastZ.moveCompleteAbsolute([nan nan obj.fastZHomePosition]);
                    else
                        obj.hFastZ.moveCompleteAbsolute([obj.fastZHomePosition nan nan]);
                    end
                end
                
                obj.zprvFastZUpdateAOData();
                if fastZBeamRewrite
                    obj.zprvBeamsWriteFastZData();
                end
                
                %obj.zprvResetTriggerTimes();
                obj.zprvResetAcqCounters();
                obj.zprvResetBuffers();
                
                obj.hAcqTasks.start();
                %obj.hLSM.arm();
                obj.hLSM.resume();
                
            else
                %Compute new FastZ AO data
                obj.zprvFastZUpdateAODataNormalized();
            end
        end
        
        %         function set.fastZNumSlices(obj,val)
        %             val = obj.validatePropArg('fastZNumSlices',val);
        %             obj.zprvFastZUpdateAOData();
        %         end
        %
        %         function set.fastZFramesPerSlice(obj,val)
        %             val = obj.validatePropArg('fastZFramesPerSlice',val);
        %             obj.zprvFastZUpdateAOData();
        %         end
        
        function set.fastZDiscardFlybackFrames(obj,val)
            obj.zprvAssertIdle('fastZDiscardFlybackFrames');
            obj.fastZDiscardFlybackFrames = val;
            
            obj.zprvFastZUpdateAODataNormalized();
        end
        
        function set.fastZFramePeriodAdjustment(obj,val)
            obj.zprvAssertIdle('fastZFramePeriodAdjustment');
            obj.fastZFramePeriodAdjustment = val;
            
            %Side effects
            obj.zprvFastZUpdateAODataNormalized();
        end
        
        function set.fastZUseAOControl(obj,val)
            obj.zprvAssertIdle('fastZUseAOControl');
            
            if obj.fastZRequireAO
                val = true;
            end
            obj.fastZUseAOControl = val;
            
            %Side effects
            obj.zprvFastZUpdateAODataNormalized();
        end        
        
        function set.fastZNumVolumes(obj,val)
            obj.zprvAssertIdle('fastZNumVolumes');
            obj.fastZNumVolumes = val;
            
            %Side effects
            obj.zprvFastZUpdateAODataNormalized();
        end
        
        function set.acqState(obj,val)
            obj.acqState = val;
        end
        
        function set.scanFrameRate(obj, val)
            obj.scanFrameRate = val;
        end
        
        function val = get.scanFrameRate(obj)
            val = obj.resonantScannerFreq*(2^obj.bidirectionalAcq)/(obj.hModel.linesPerFrame+obj.hModel.flybackLinesPerFrame);
        end
        
        function val = get.scanFramePeriod(obj)
            val = 1 / obj.scanFrameRate;
        end
        
        function set.stackZStepSize(obj,val)
            obj.stackZStepSize = val;
        end
    end
    
    %% HIDDEN INITIALIZATION METHODS
    methods (Hidden)
        %******************************************************************
        %PIEZO (FAST Z STAGE)
        %******************************************************************
        function ziniPrepareFastZ(obj)
            obj.fastZAvailable = ~isempty(obj.mdfData.fastZControllerType);
            if ~obj.fastZAvailable
                fprintf('No FastZ controller specified in Machine Data File. Feature disabled.\n');
                return;
            end
            
            useMotor2 = false;
            try
                
                %Construct & initialize fastZ object in hardware-specific manner
                if obj.fastZSecondMotor
                    useMotor2 = true;
                    
                    controllerType = obj.hModel.hMotors.mdfData.motor2ControllerType;
                    assert(~isempty(controllerType),'FastZ motor controller was configured as ''useMotor2'', but no secondary Z motor was actually specified.');
                    assert(~isempty(obj.hModel.hMotors.hMotorZ),'FastZ motor controller was configured as ''useMotor2'', but secondary Z motor was not successfully configured.');
                    
                    comPort = obj.hModel.hMotors.mdfData.motor2COMPort;
                    baudRate = obj.hModel.hMotors.mdfData.motor2BaudRate;
                else
                    controllerType = obj.mdfData.fastZControllerType;
                    comPort = obj.mdfData.fastZCOMPort;
                    baudRate = obj.mdfData.fastZBaudRate;
                end
                
                if useMotor2
                    obj.hFastZ = obj.hModel.hMotors.hMotorZ;
                end
                
                %Initialize fastZ AO object, if specified & not done so already
                if ~isempty(obj.mdfData.fastZAOChanID) && isempty(obj.hFastZAO)
                    znstInitFastZAO();
                end
                
                switch lower(controllerType)
                    
                    case {'pi.e816' 'pi.e665'} %E665 uses E816 controller under hood     
                        analogCmdArgs = {};
                        znstInitFastZ(@dabs.pi.LinearStageController,[{'controllerType','e816','comPort',comPort,'baudRate',baudRate} analogCmdArgs]);
                    
                    case {'pi.e709' 'pi.e753'}
                        analogCmdArgs = {};
                        znstInitFastZ(@dabsv.pi.LinearStageController,[{'controllerType','e753','comPort',comPort,'baudRate',baudRate} analogCmdArgs]);
                        
                    case {'npoint.lc40x'}
                        analogCmdArgs = {};
                        znstInitFastZ(@dabs.npoint.LinearStageController,[{'controllerType','LC40x','comPort',comPort,'baudRate',baudRate} analogCmdArgs]);
                        
                    case {'simulated.piezo'}
                        analogCmdArgs = {};
                        znstInitFastZ(@dabs.simulated.Piezo,analogCmdArgs);
                        
                    case {'analog'}
                        if ~useMotor2
                            numDeviceDimensions = numel(obj.mdfData.analogCmdChanIDs);
                            assert(numDeviceDimensions > 0,'One or more analogCmdChanIDs must be specified for Analog LSC');
                            
                            hLSC = dabs.generic.LSCPureAnalog('numDeviceDimensions',numDeviceDimensions);
                            obj.hFastZ = scanimage.StageController(hLSC);
                        else
                            hLSC = obj.hModel.hMotors.hMotorZ.hLSC;
                        end
                        
                        %Create/configure fastZAO Task, coordinated with static AO Task maintained by LSC
                        znstInitFastZAO(hLSC);
                        obj.hFastZ.initializeAnalogOption('hAOBuffered',obj.hFastZAO);
                                                                       
                        
                    otherwise
                        assert(false,'FastZ controller type specified (''%s'') is unrecognized or presently unsupported',controllerType);
                        
                end
                
                
                %                 %If in all-analog mode, forcibly start FastZ in middle of range
                %                 if obj.hFastZ.analogCmdEnable
                %                     obj.hFastZ.moveToCenter();
                %                 end
                
                
            catch ME
                fprintf(2,'Error occurred while initializing fastZ hardware. Incorrect MachineDataFile settings likely cause. \n Disabling motor feature. \n Error stack: \n  %s \n',ME.getReport());
                
                obj.fastZAvailable = false;
                
                if ~isempty(obj.hFastZ) && ~useMotor2
                    delete(obj.hFastZ);
                end
                
                obj.hFastZ = [];
            end
            
            function znstInitFastZ(xtor,xtorArgs)
                %Require AO Task be used for FastZ, where available
                znstRequireFastZAO();
                
                %TODO: Make ctor call logic programmatic, based on controllerType string
                if ~useMotor2
                    hLSC = feval(xtor,xtorArgs{:});
                    obj.hFastZ = scanimage.StageController(hLSC);
                end
                
                %Initialize analog command option
                args = {'analogCmdBoardID', obj.hFastZAO.deviceNames{1},'analogCmdChanIDs',obj.mdfData.fastZAOChanID,'hAOBuffered',obj.hFastZAO};
                if ~isempty(obj.mdfData.fastZAIChanID) && ~isempty(obj.mdfData.fastZAIDeviceID)
                    args = [args {'analogSensorBoardID' obj.mdfData.fastZAIDeviceID 'analogSensorChanIDs' obj.mdfData.fastZAIChanID}];
                end
                obj.hFastZ.initializeAnalogOption(args{:});
                
                %Set analog-controllable LSC to use analog mode
                obj.hFastZ.analogCmdEnable = true;
            end
            
            function znstRequireFastZAO()
                if isempty(obj.mdfData.fastZAOChanID)
                    throwAsCaller(MException('','Analog Output (AO) Task required for specified FastZ hardware type (''%s'')',obj.mdfData.fastZControllerType));
                end
                
                %znstInitFastZAO();
                obj.fastZRequireAO = true;
                obj.fastZUseAOControl = true;
            end
            
            function znstInitFastZAO(src)
                
                if nargin == 0 %Use MDF
                    
                    obj.zprvMDFVerify('fastZAODeviceName',{{'char'},{'nonempty'}},[]);
                    obj.zprvMDFVerify('fastZAOChanID',{{'numeric'},{'integer' 'scalar'}},[]);
                    
                    obj.hDaqDevice = dabs.ni.daqmx.Device(obj.mdfData.fastZAODeviceName);
                    obj.detectPxiChassis(); % check if daq device is part of main PXI chassis and update obj.mdfData.frameClockIn accordingly
                    
                    obj.zprvMDFVerify('frameClockIn',{{'char'},{'vector','nonempty'}},[]);
                    
                    fastZAODeviceName = obj.mdfData.fastZAODeviceName;
                    fastZAOChanID = obj.mdfData.fastZAOChanID;

                    
                else
                    fastZAODeviceName = src.analogCmdBoardID;
                    fastZAOChanID = src.analogCmdChanIDs(end);
                   
                end
                
                obj.extFrameClockTerminal = obj.mdfData.frameClockIn;
                
                %obj.hFastZAO = obj.zprvDaqmxTask('FastZ AO');
                obj.hFastZAO = scanimage.util.priv.safeCreateTask('FastZ AO'); %HACK
                obj.hFastZAO.createAOVoltageChan(fastZAODeviceName,fastZAOChanID);
                fprintf('obj.mdfData.fastZAODeviceName: %s, obj.mdfData.fastZAOChanID: %d\n',obj.mdfData.fastZAODeviceName,obj.mdfData.fastZAOChanID);
                
                obj.fastZAOOutputRate = obj.hFastZAO.get('sampClkMaxRate');
                
                obj.hFastZAO.cfgSampClkTiming(obj.fastZAOOutputRate, 'DAQmx_Val_FiniteSamps');
                obj.hFastZAO.cfgDigEdgeStartTrig(obj.extFrameClockTerminal);
                fprintf('Setting up extFrameClockTerminal on %s...\n',obj.extFrameClockTerminal);
                obj.hFastZAO.set('startTrigRetriggerable',true);
                
                %                 hChan = obj.hFastZAO.channels(1);
                %                 obj.fastZAORange = [hChan.get('min') hChan.get('max')];
                
                
                %Start AO Task in middle of scanner range
                %                 rMin = obj.hFastZ.hStage.get('rangeLimitMin');
                %                 rMax = obj.hFastZ.hStage.get('rangeLimitMax');
                %
                %                 obj.hFastZAOPark.writeAnalogData(obj.zprvFastZPosn2Voltage(rMin+(rMax-rMin)/2));
            end
        end    
        
        function inPxiChassis = detectPxiChassis(obj)
            inPxiChassis = false;
            if isempty(obj.hModel) || ~isvalid(obj.hModel)
                 % adapter is not called from SI5.m PXI routing is not available
                 return
            end
            
            inPxiChassis = obj.hModel.hTriggerMatrix.isDeviceInMainPxiChassis(obj.mdfData.fastZAODeviceName);
            if inPxiChassis
                obj.mdfData.frameClockIn = obj.hModel.hTriggerMatrix.PXI_TRIGGER_MAP('frameClock');
                fprintf('FastZ: Set frameClockIn to ''%s''\n',obj.mdfData.frameClockIn);
            end
        end

    end
end

%--------------------------------------------------------------------------%
% FastZ.m                                                                  %
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
