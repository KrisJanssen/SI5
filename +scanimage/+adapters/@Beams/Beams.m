classdef Beams < most.MachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Beams';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %% PUBLIC PROPS
    
    
    %Parent coupled properties
    properties (SetObservable)
        beamNumBeams;
        acqState = 'idle'; %One of {'focus' 'grab' 'loop' 'idle'}
        
        %internal set flag (What is this used for??)
        internalSetFlag = false;
        
        beamFlybackBlanking = true; %Logical indicating whether to blank beam outside of fill fraction
        beamPowers = [10]; %Numeric array containing power values for each beam
        beamPowerLimits = [100]; %Numeric array containing power limit for each beam
        beamLiveAdjust = true; %Logical indicating whether beamPowers can be adjusted during scanning. Doing so will disable flyback blanking, if enabled.
        beamDirectMode = false; %Logical indicating that power should be turned on and take effect immediately after all beamPowers adjustments
        beamPowerUnits = 'percent'; %One of {'percent', 'milliwatts'}
        beamPzAdjust = [false]; %Logical array indicating whether power/z adjustment is enabled for each beam
        beamLengthConstants = inf; %Numeric array containing length constant for each beam, to use for power adjustment during Z stacks
        beamVoltageRanges; %Nbeam x 1 numeric. Maximum voltage for each beam.
        beamIDs;
        
        stackGrabActive = false;
        fastZActive = false;
        fastZEnable = false;
        fastZAllowLiveBeamAdjust = false; %Logical indicating whether to allow live adjustment of beamPowers during fastZ imaging.
        
        acqBeamLengthConstants; %Beam power length constants for use in actual acquistion; can differ from beamLengthConstants due to stackOverrideLz, etc
        acqBeamPowersStackStart; %Beam powers at last start of stack
        
        % StackZ imaging properties
        stackUserOverrideLz=false;
        stackStartPower=nan; % beam-indexed
        stackEndPower=nan; % beam-indexed
        stackZStartPos;
        stackZEndPos;
        stackZStepSize=1; %distance in microns
        stackUseStartPower=false;
        
        % Triggering properties
        extLineClockTerminal; %local copy of extLineClockTerminal as defined in SI5 class.
        
        % Values assigned from SI5 parent object.
        scanLinePeriod = 0.00012642225;
        scanMode='bidirectional'; %One of {'unidirectional' 'bidirectional'}
        scanFillFraction=0.90; %<Range 0..1> Specifies fraction of line period during which acquisition occurs
        linesPerFrame=0;
        acqNumFrames;
        stackNumSlices;
        fastZNumDiscardFrames=0;
%        fastZNumFramesPerVolume;
        fastZNumVolumes;
        fastZImageType;
        stackStartCentered;
        maxSampleRate;
    end
    
    properties (SetObservable,Dependent)
        stackStartPowerDefined;
        stackEndPowerDefined;
    end
    
    properties (Hidden,SetAccess=protected,Dependent)
        stackStartEndPointsDefined;
        stackStartEndPowersDefined; % logical; if true, stackZStartPower, stackZEndPower are defined
        fastZNumFramesPerVolume;
        acqNumFramesPerTrigger;
    end
    
    %Fudge-factors
    properties (Hidden)
        beamCalibrationLUTSize = 1e3; % number of steps in calibration LUT
        beamCalibrationNumVoltageSteps = 100; % number of beam voltage steps to use (during beam calibration)
        beamCalibrationNumPasses = 5; % number of voltage sweeps to perform
        beamCalibrationIntercalibrationZeros = 4; % number of zero voltage samples to apply between calibration sweeps
        beamCalibrationOutputRate = 1e5; % output sample rate of beam/beamCal tasks during calibration
        beamCalibrationIntercalibrationPauseTime = 0.2; % (seconds) pause time between calibration sweeps
        beamCalibrationOffsetNumSamples = 1e4; % Number of samples to take when measuring calibration offset
        beamCalibrationNoisyOffsetThreshold = 0.15; % Warning thrown if stddev/mean > (this ratio) while measuring photodiode offset
        beamCalibrationFluctuationThreshold = 0.35; % (dimensionless) warn if the std_dev/max of the beamCal signal exceeds this threshold
        beamCalibrationMinThreshold = 0.15; % (dimensionless) warn if min/max of the beamCal signal exceeds this threshold
    end
    
    %% INTERNAL PROPS
    properties (Hidden,SetAccess=protected)
        hModel;
        
        hBeamsTask;
        hBeamsPark; %Same as hBeams -- separate Task used for static power control adjustments
        hBeamCals; %Array of AI Tasks for beam modulation calibratin (e.g. with photodiodes)

        hDaqDevice;
        daqDevBusType;
        daqDevPxiChassis;
        daqDevPxiSlot;
        
        beamFlybackBlankData; %Array of beam output data for each scanner period for flyback blanking mode. Array has one column for each beam.
        beamFlybackBlankDataMask; %Mask representation of beamFlybackBlankData, with 1 values representing beam ON and NaN representing beam OFF.
        beamCalibrationLUT; %beamCalibrationLUTSize x numBeams array. lut(i,j) gives the beam voltage necessary to achieve the fraction (i/beamCalibrationLUTSize) of the maximum beam power for beam j.
        beamCalibrationMinCalVoltage; %1 x numBeams array. Gives the minimum beam calibration voltage encountered during calibration for each beam.
        beamCalibrationMaxCalVoltage; %1 x numBeams array. Gives the maximum beam calibration voltage encountered during calibration for each beam.
        beamCalibrationMinAchievablePowerFrac; % 1 x numBeams array. Gives the minimum achievable power fraction for each beam
        beamCancelCalibration = false; %Logical set/polled if user cancels during beam calibration.
        beamPowersNominal; %Last-set values of beamPowers, which may be at higher precision than calibration-constrained beamPowers value
        
        beamOnPowerVoltages; %Beam-indexed voltage levels corresponding to power fraction percentages in beamPowers
        beamOffPowerVoltages; %Beam-indexed voltage levels corresponding to minimum achievable beam power fractions
        
        fastZBeamPowersCache; %Cache of beamPowers data, maintained if fastZAllowLiveBeamAdjust=true
        fastZBeamWriteOffset; %Store the offset to next write to FastZ Beam AO Task
        fastZBeamNumBufferedVolumes = 1; %Number of volumes to buffer. Any changes to beam params will take places with latency of (fastZBeamNumBufferedVolumes-1) volumes

    end
    
    %% LIFECYCLE
    methods
        function obj = Beams(hModel)
            if nargin < 1 || isempty(hModel)
                hModel = [];
            end
            obj.hModel = hModel;
            
            obj.ziniPrepareBeams(); %Initialize optional hardware for 'beam' modulation (e.g. Pockels), including calibration (e.g. with photodiode)
            if obj.beamNumBeams > 0
                obj.ziniCalibrateBeams();
            end
        end
        
        function delete(obj)
            if ~isempty(obj.hBeamsTask)
                obj.hBeamsTask.stop();
                delete(obj.hBeamsTask);
                clear obj.hBeamsTask;
            end
            
            if ~isempty(obj.hBeamsPark)
                obj.hBeamsPark.stop();
                delete(obj.hBeamsPark);
                clear obj.hBeamsPark;
            end
            
            for i = 1:numel(obj.hBeamCals)
                if ~isempty(obj.hBeamCals{i}) && isvalid(obj.hBeamCals{i})
                    obj.hBeamCals{i}.stop();
                    delete(obj.hBeamCals{i});
                end
            end
        end
    end
    
    %% PUBLIC ACCESS METHODS
    methods
        function beamsStandby(obj)
            %Turns off beam channel(s) and prepares them for next acquisition
            if obj.beamNumBeams > 0
                obj.beamsOff();
                obj.zprvBeamsWriteFlybackData();
            end
        end
        
        function beamsOn(obj)
            if obj.beamNumBeams > 0
                obj.hBeamsTask.control('DAQmx_Val_Task_Unreserve'); %should flush data
                obj.hBeamsPark.writeAnalogData(obj.beamOnPowerVoltages);
            end
        end
        
        function beamsOff(obj)
            if obj.beamNumBeams > 0
                obj.hBeamsTask.abort();
                obj.hBeamsTask.control('DAQmx_Val_Task_Unreserve'); %should flush data
                obj.hBeamsPark.writeAnalogData(obj.beamOffPowerVoltages);
            end
        end
        
        function beamsCalibrate(obj,beamIdx,showShutterWarning)
            % Run calibration of beam modulation device. Sets the properties beamCalibrationLUT,
            % beamCalibrationMin/MaxCalVoltage for beamIdx'th beam.
            
            % Note: This is basically the only safe way to set any of these
            % three properties.
            
            if nargin < 2 || isempty(beamIdx)
                beamIdx = 1:obj.beamNumBeams;
            end
            
            if nargin < 3 || isempty(showShutterWarning)
                showShutterWarning = false;
            end
            
            validateattributes(beamIdx,{'numeric'},{'vector','integer','>=',1,'<=',obj.beamNumBeams});
            
            switch obj.acqState
                case 'idle'
                    % none
                otherwise
                    error('SI5:beamsCalibrate:acquisitionRunning',...
                        'Cannot calibrate beams during acquisition.');
            end
            
            if obj.mdfData.shutterBeforeBeam
                for bIdx = beamIdx(:)'
                    obj.beamsMeasureCalOffset(bIdx,true);
                end
            else
                % Will use current offset from mdfData. If desired, user
                % should separately run offset measurement before
                % calibration.
            end
            
            try
                if obj.mdfData.shutterBeforeBeam
                    if showShutterWarning
                        uiwait(msgbox('Warning: Shutter will open for pockels calibration.','Alert','modal'));
                    end
                    obj.hModel.hShutters.shuttersTransition(true);
                end
                
                for bIdx = beamIdx(:)'
                    rejectedLight = obj.mdfData.beamCalUseRejectedLight(bIdx);
                    
                    [tfSuccess beamCalVoltage beamVoltage] = obj.zprvBeamsGetCalibrationData(bIdx);
                    
                    if tfSuccess
                        if isempty(beamCalVoltage) %No calibration chan for this beam
                            [lut beamCalMinVoltage beamCalMaxVoltage] = ...
                                obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
                        else
                            [lut beamCalMinVoltage beamCalMaxVoltage] = ...
                                obj.zprvBeamsProcessCalibrationData(beamVoltage,beamCalVoltage,obj.mdfData.beamCalOffsets(bIdx),rejectedLight);
                        end
                    else
                        fprintf(2,'WARNING: Unable to collect beam calibration data for ''%s''. Using naive calibration.\n',obj.mdfData.beamIDs{bIdx});
                        [lut beamCalMinVoltage beamCalMaxVoltage] = ...
                            obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
                    end
                    
                    %Update beam calibration properties
                    obj.zprvBeamsSetCalibrationInfo(bIdx,lut,beamCalMinVoltage,beamCalMaxVoltage);
                end
                
                if obj.mdfData.shutterBeforeBeam
                    obj.hModel.hShutters.shuttersTransition(false);
                end
            catch ME
                obj.hModel.hShutters.shuttersTransition(false);
                rethrow(ME);
            end
        end
        
        function offset = beamsMeasureCalOffset(obj,beamIdx,tfWriteToMDF)
            % Measures and updates stored offset value for beam calibration
            % device (e.g. photodiode). Corrects subsequent readings with
            % that device, to improve calibration accuracy.
            
            % Updates obj.mdfData.beamCalOffsets. If tfWriteToMDF is true,
            % this also updates the current MDF.
            
            if nargin < 3
                tfWriteToMDF = false;
            end
            if nargin < 2 && obj.beamNumBeams==1
                beamIdx = 1;
            end
            
            validateattributes(beamIdx,{'numeric'},{'scalar','integer','>=',1,'<=',obj.beamNumBeams});
            
            switch obj.acqState
                case 'idle'
                    % none
                otherwise
                    error('SI5:beamsMeasureCalOffset:acquisitionRunning',...
                        'Cannot calibrate beam during acquisition.');
            end
            
            beamCalTask = obj.hBeamCals{beamIdx};
            if isempty(beamCalTask)
                fprintf(2,'WARNING: Unable to measure beam calibration offset for ''%s''. No calibration input channel defined in MDF. \n',obj.mdfData.beamIDs{beamIdx});
                offset = NaN;
                return
            end
            
            beamCalTask.control('DAQmx_Val_Task_Unreserve');
            beamCalTask.cfgSampClkTiming(obj.beamCalibrationOutputRate,'DAQmx_Val_FiniteSamps',obj.beamCalibrationOffsetNumSamples);
            beamCalTask.set('startTrigRetriggerable',false);
            beamCalTask.disableStartTrig();
            
            sampleTime = obj.beamCalibrationOffsetNumSamples/obj.beamCalibrationOutputRate;
            
            if obj.mdfData.shutterBeforeBeam
                % shutter should probably already be off, but anyway
                obj.hModel.hShutters.shuttersTransition(false);
            else
                uiwait(msgbox(sprintf('Turn off laser for beam index %d.',beamIdx),'Alert','modal'));
            end
                        
            beamCalTask.start;
            data = beamCalTask.readAnalogData(obj.beamCalibrationOffsetNumSamples);
            beamCalTask.stop();
            
            offset = mean(data);
            sig = std(data);
            if sig/offset > obj.beamCalibrationNoisyOffsetThreshold
                warning('SI5:beamsMeasureCalOffset:noisyPhotodiodeOffset',...
                    'Noisy photodiode offset.');
            end
            
            assert(numel(obj.mdfData.beamCalOffsets)==obj.beamNumBeams);
            obj.mdfData.beamCalOffsets(beamIdx) = offset;
            
            if tfWriteToMDF
                mdf = most.MDF.getInstance();
                if mdf.isLoaded
                    %Load all existing beam cal offsets from MDF file.
                    allOffsets = obj.mdfData.beamCalOffsets;
                    %No matter what the orientation of the existing beam
                    %cal offsets is, force into a 1x2 matrix.
                    allOffsets = reshape(allOffsets,1,obj.beamNumBeams);
                    %Set the appropriate beam indices with the new
                    %calibrated values.
                    allOffsets(beamIdx) = offset;
                    %Write back beam cal offsets into MDF file.
                    mdf.writeVarToHeading('Beams','beamCalOffsets',allOffsets);
                end
            end
        end
        
        function beamsShowCalibrationCurve(obj,beamIdx)
            %Displays figure showing last measured/computed calibration of beam modulation device, for specified beamIdx
            
            validateattributes(beamIdx,{'numeric'},{'scalar','integer','>=',1,'<=',obj.beamNumBeams});
            chart_title = sprintf('Look Up Table (Beam %d)', beamIdx);
            h = figure('NumberTitle','off','DoubleBuffer','On','Name',chart_title,'Color','White');
            a = axes('Parent',h);
            plot(obj.beamCalibrationLUT(:,beamIdx),(1:obj.beamCalibrationLUTSize)'/obj.beamCalibrationLUTSize*100,...
                'Marker','o','MarkerSize',2,'LineStyle','none','Parent',a,...
                'MarkerFaceColor',[0 0 0],'color',[0 0 0]);
            title(chart_title,'FontSize',12,'FontWeight','Bold','Parent',a);
            ylabel('Percent of Maximum Power','Parent',a,'FontWeight','bold');
            xlabel('Modulation Voltage [V]','Parent',a,'FontWeight','bold');
            
            axisRange = axis;
            lblXPos = axisRange(1) + (axisRange(2)-axisRange(1))/3;
            lblYPos = axisRange(3) + (axisRange(4)-axisRange(3))*92/100;
            minCalV = obj.beamCalibrationMinCalVoltage(beamIdx);
            maxCalV = obj.beamCalibrationMaxCalVoltage(beamIdx);
            
            extRatio = maxCalV/minCalV;
            if extRatio > 1000
                extRatio = '>1000';
            end
            
            zlclAddQuantityAnnotations(a,lblXPos,lblYPos,...
                {'Cal. Offset';'Min Cal. Voltage';'Max Cal. Voltage';'Max Extinction Ratio'},...
                {obj.mdfData.beamCalOffsets(beamIdx);minCalV;maxCalV;extRatio},'FontWeight','bold','FontSize',9);
            % TODO are these figHandles going somewhere
        end
        
        function acqLzs = beamComputeOverrideLzs(obj)
            %Displays figure showing last measured raw calibration data
            %obtained for beam modulation device of specified beamIdx
            
            Nbeam = obj.beamNumBeams;
            beamLz = obj.beamLengthConstants;
            assert(isequal(numel(beamLz),numel(obj.stackEndPower),numel(obj.stackStartPower),Nbeam));
            if obj.fastZEnable
                dz = obj.stackNumSlices * obj.stackZStepSize;
            else
                dz = obj.stackZEndPos-obj.stackZStartPos;
            end
            acqLzs = inf(Nbeam,1);
            for c = 1:Nbeam
                if obj.beamPzAdjust(c)
                    Pratio = obj.stackEndPower(c)/obj.stackStartPower(c);
                    acqLzs(c) = dz/log(Pratio);
                    fprintf(1,'Beam %d: Lz=%.2f\n',c,acqLzs(c));
                end
            end
        end
        
        function val = zprpBeamScalarExpandPropValue(obj,val,propName)
            if isscalar(val)
                %val = repmat(val,obj.beamNumBeams,1);
                val = repmat(val,1,obj.beamNumBeams);
            else
                assert(numel(val)==obj.beamNumBeams,...
                    'The ''%s'' value must be a vector of length %d -- one value for each beam',...
                    propName,obj.beamNumBeams);
            end
        end
        
        function voltage = zprpBeamsPowerFractionToVoltage(obj,beamIdx,powerFrac)
            % Use the calibration LUT to look up the beam voltage needed to
            % achieve a certain beam power fraction.
            % powerFrac: real number vector on [0,1].
            % voltage: beam voltage vector that will achieve powerFrac
            
            validateattributes(beamIdx,{'numeric'},{'vector','integer','>=',1,'<=',obj.beamNumBeams});
            validateattributes(powerFrac,{'numeric'},{'vector','>=',0});
            
            powerFrac = max(powerFrac,obj.beamCalibrationMinAchievablePowerFrac(beamIdx));
            cappedIdxs = find(powerFrac > 1);
            if ~isempty(cappedIdxs)
                fprintf(2,'WARNING(%s): A power fraction > 1.0 was requested for beam %d (''%s''). Power capped at maximum value determined during last calibration.\n',class(obj),beamIdx,obj.mdfData.beamIDs{beamIdx});
            end
            
            powerFrac = max(powerFrac,obj.beamCalibrationMinAchievablePowerFrac(beamIdx));
            powerFrac(cappedIdxs) = 1.0;
            
            lutIdx = max(1,ceil(powerFrac*obj.beamCalibrationLUTSize)); % use ceil for now, minimum value of 1
            voltage = obj.beamCalibrationLUT(lutIdx,beamIdx);
            %assert(~isnan(voltage)); comment these for now b/c during SI4 construction/initialization, this method is called before the beams are calibrated.
            %assert(voltage <= obj.beamVoltageRanges(beamIdx));
        end
        
        function val = get.beamOnPowerVoltages(obj)
            bmPowers = obj.beamPowers;
            for c = obj.beamNumBeams:-1:1
                val(c) = obj.zprpBeamsPowerFractionToVoltage(c,bmPowers(c)/100.0);
            end
        end
        
        function val = get.beamOffPowerVoltages(obj)
            for c = obj.beamNumBeams:-1:1
                val(c) = obj.zprpBeamsPowerFractionToVoltage(c,0.0);
            end
        end
        
        function val = get.acqNumFramesPerTrigger(obj)
            if ~obj.fastZEnable
                val = obj.acqNumFrames;
            else
                switch obj.fastZImageType
                    case {'XY-Z' 'XZ-Y'}
                        val = obj.fastZNumFramesPerVolume * obj.fastZNumVolumes;
                    case {'XZ'}
                        val = obj.fastZNumFramesPerVolume;
                end
            end
        end
        
        function val = get.fastZNumFramesPerVolume(obj)
            switch obj.fastZImageType
                case 'XY-Z'
                    %Discarded frames, if any, apply per-volume
                    val = (obj.acqNumFrames * obj.stackNumSlices + obj.fastZNumDiscardFrames);
                case 'XZ'
                    %Discarded frames, if any, apply per-frame
                    val = obj.acqNumFrames * (1 + obj.fastZNumDiscardFrames);
                case 'XZ-Y'
                    %numSlices taken to mean # of Y slices in this case
                    %Discarded frames, if any, apply per-volume
                    val = (obj.acqNumFrames * obj.stackNumSlices + obj.fastZNumDiscardFrames);
            end
        end
        
        function set.scanMode(obj, val)
            obj.scanMode = val;
            
            %Side effects
            obj.zprvBeamsUpdateFlybackBuffer();
        end
        
        function set.scanFillFraction(obj, val)
            obj.scanFillFraction = val;
            
            %Side effects
            obj.zprvBeamsUpdateFlybackBuffer();
        end
        
        function set.stackZStartPos(obj,val)
            obj.stackZStartPos=val;
        end
        
        function set.stackZEndPos(obj,val)
            obj.stackZEndPos=val;
        end
        
        function set.stackStartPower(obj,val)
            val = obj.zprpBeamScalarExpandPropValue(val,'stackStartPower');
            obj.stackStartPower = val;
            
            %Side effects
            obj.acqBeamLengthConstants = []; %Force recompute on next use
        end
        
        function set.stackEndPower(obj,val)
            val = obj.zprpBeamScalarExpandPropValue(val,'stackEndPower');
            obj.stackEndPower = val;
            
            %Side effects
            obj.acqBeamLengthConstants = []; %Force recompute on next use
        end
        
        function val = get.stackStartPower(obj)
            val = obj.stackStartPower;
        end
        
        function val = get.stackEndPower(obj)
            val = obj.stackEndPower;
        end
        
        function set.beamNumBeams(obj,val)
            obj.beamNumBeams = val;
        end
        
        function val = get.beamNumBeams(obj)
            val = obj.beamNumBeams;
        end
        
        function v = get.stackStartEndPointsDefined(obj)
            v = true;
            for beamIndex = 1:obj.beamNumBeams
                v = v && (~isnan(obj.stackZStartPos(beamIndex)) && ~isnan(obj.stackZEndPos(beamIndex)));
            end            
        end
        
        function v = get.stackStartPowerDefined(obj)
            v = true;
            for beamIndex = 1:obj.beamNumBeams
                v = v && (~isnan(obj.stackStartPower(beamIndex)));
            end
        end
        
        function v = get.stackEndPowerDefined(obj)
            v = true;
            for beamIndex = 1:obj.beamNumBeams
                v = v && (~isnan(obj.stackEndPower(beamIndex)));
            end
        end
        
        function v = get.stackStartEndPowersDefined(obj)
            %TODO: this is beam-idxed
            %Ed: Initially, the model has been to use the number of
            %elements in the stackstartpower and stackendpower values to
            %determine the number of beams. This is problematic if there
            %are no beams because ~isnan of an empty array is an empty
            %array, and performing the logical && for two empty arrays
            %results in an error in matlab.
            %
            %So first check to see if obj.stackStartPower and
            %obj.stackEndPower are defined.
            v = true;
            for beamIndex = 1:obj.beamNumBeams
                v = v && (~isnan(obj.stackStartPower(beamIndex)) && ~isnan(obj.stackEndPower(beamIndex)));
            end
        end
        
        function val = get.acqBeamLengthConstants(obj)
            %Empty value acqBeamLengthConstants signals need to recompute (if any beams)
            if isempty(obj.acqBeamLengthConstants) && ~isempty(obj.beamNumBeams)
                obj.acqBeamLengthConstants = inf(obj.beamNumBeams,1);
                obj.acqBeamLengthConstants(logical(obj.beamPzAdjust)) = obj.beamLengthConstants(logical(obj.beamPzAdjust));
                
                if obj.stackUserOverrideLz && obj.stackStartEndPointsDefined && obj.stackStartEndPowersDefined && ~obj.fastZEnable
                    obj.acqBeamLengthConstants = obj.beamComputeOverrideLzs();
                end
            end
            
            val = obj.acqBeamLengthConstants;
        end
        
        function set.beamDirectMode(obj,val)
            obj.zprvAssertIdle('beamDirectMode');
            %             val = obj.validatePropArg('beamDirectMode',val);
            if obj.beamDirectMode && obj.isIdle && ~val
                obj.beamsStandby();
            end
            obj.beamDirectMode = val;
        end
        
        function set.beamFlybackBlanking(obj,val)
            obj.zprvAssertFocusOrIdle('beamFlybackBlanking');
            %             val = obj.validatePropArg('beamFlybackBlanking',val); %allow during acq
            obj.beamFlybackBlanking = val;
            
            %Dependencies
            obj.zprvBeamsUpdateFlybackBuffer();
        end
        
        function set.beamLengthConstants(obj,val)
            obj.zprvAssertFocusOrIdle('beamLengthConstants');
            %             val = obj.validatePropArg('beamLengthConstants',val);
            val = obj.zprpBeamScalarExpandPropValue(val,'beamLengthConstants');
            obj.beamLengthConstants = val;
            
            %Side effects
            obj.acqBeamLengthConstants = []; %Force recompute on next use
        end
        
        function set.beamPowers(obj,val)
            obj.zprvAssertFocusOrIdle('beamPowers');
            %             val = obj.validatePropArg('beamPowers',val);
            
            %            liveRefresh = obj.fastZActive && obj.fastZAllowLiveBeamAdjust && (obj.beamFlybackBlanking || obj.beamPzAdjust); %Currently, preliminary support for live power adjustment during FastZ volume imaging is implemented
            liveRefresh = obj.fastZActive && obj.fastZAllowLiveBeamAdjust && (obj.beamFlybackBlanking || any(obj.beamPzAdjust)); %Currently, preliminary support for live power adjustment during FastZ volume imaging is implemented
            
            %            assert(liveRefresh || ismember(obj.acqState,{'idle' 'focus'}) || ~obj.hLSM.isAcquiring(),'Live power adjustment during non-Focus acquisition is not permitted under current settings');
            %TODO: SI4 code was checking for acq state of hLSM object, but
            %acqState var should hold this data regardless.
            assert(obj.stackGrabActive || liveRefresh || ismember(obj.acqState,{'idle' 'focus'}),'Live power adjustment during non-Focus acquisition is not permitted under current settings');
            
            val = obj.zprpBeamScalarExpandPropValue(val,'beamPowers');
            
            %Set nominal and resolution-constrained value
            val = obj.zprvBeamEnforcePowerLimits(val);
            obj.beamPowersNominal = val;
            
            if strcmpi(obj.beamPowerUnits,'percent')
                factor = obj.beamCalibrationLUTSize/100;
                val = max(round(factor*val),1)/factor; %Only allow precision to 0.1
            end
            
            obj.beamPowers = val;
            
            %Side effects
            
            %Update the model's beamsPowersDisplay property
            obj.hModel.beamPowersDisplay = val;
            
            %Handle direct mode
            if obj.beamDirectMode && obj.isIdle()
                obj.beamsOn();
            end
            
            if liveRefresh
                obj.zprvBeamsRefreshFastZData();
            else
                obj.zprvBeamsUpdateFlybackBuffer();
            end
        end
        
        function set.acqState(obj,val)
            obj.acqState = val;
        end
        
        %Set stackGrabActive to TRUE if doing a grab or loop with slices.
        function set.stackGrabActive(obj,val)
            obj.stackGrabActive = val;
        end
        
        %Set stackGrabActive to TRUE if doing a grab or loop with slices.
        function val = get.stackGrabActive(obj)
            val = obj.stackGrabActive;
        end
        
        function set.fastZEnable(obj,val)
            obj.fastZEnable = val;
        end
        
        function val = get.fastZEnable(obj)
            val = obj.fastZEnable;
        end
        
        function set.fastZActive(obj,val)
            obj.fastZActive = val;
        end
        
        function val = get.fastZActive(obj)
            val = obj.fastZActive;
        end
        
        function set.beamPowerLimits(obj,val)
            obj.zprvAssertIdle('beamPowerLimits');
            %             val = obj.validatePropArg('beamPowerLimits',val);
            val = obj.zprpBeamScalarExpandPropValue(val,'beamPowerLimits');
            
            switch obj.beamPowerUnits
                case 'percent'
                    validateattributes(val,{'numeric'},{'>=',0,'<=',100});
                case 'milliwatts'
                    % TODO
            end
            obj.beamPowerLimits = val;
            
            %Side-effects
            obj.beamPowers = obj.zprvBeamEnforcePowerLimits(obj.beamPowers);
        end
        
        function set.beamPzAdjust(obj,val)
            obj.zprvAssertIdle('beamPzAdjust');
            %             val = obj.validatePropArg('beamPzAdjust',val);
            val = obj.zprpBeamScalarExpandPropValue(val,'beamPzAdjust');
            obj.beamPzAdjust = val;
            
            %Side effects
            obj.zprvBeamsUpdateFlybackBuffer();
            obj.acqBeamLengthConstants = []; %Force recompute on next use
            
        end
        
        function set.beamVoltageRanges(obj,val)
            obj.zprvAssertIdle('beamVoltageRanges');
            %             val = obj.validatePropArg('beamVoltageRanges',val);
            val = obj.zprpBeamScalarExpandPropValue(val,'beamVoltageRanges');
            validateattributes(val,{'numeric'},{'>=',0});
            if ~isequal(val,obj.beamVoltageRanges)
                obj.beamVoltageRanges = val;
                %TODO
                %                 switch obj.initState
                %                     % Don't throw this warning during construction/initialization
                %                     case 'none'
                %                         warning('SI5:setBeamVoltageRanges',...
                %                             'Any beam whose voltage range has changed should be recalibrated.');
                %                 end
            end
        end
    end
    
    %% HIDDEN INITIALIZATION METHODS
    methods (Hidden)
        function ziniDisableBeamsFeature(obj)
            obj.beamNumBeams = 0;
            obj.beamPowers = [];
            obj.beamPowerLimits = [];
            
            if ~isempty(obj.hBeamsTask)
                delete(obj.hBeamsTask);
            end
            obj.hBeamsTask = dabs.ni.daqmx.Task.empty();
            
            for i=1:length(obj.hBeamCals)
                if ~isempty(obj.hBeamCals{i})
                    delete(obj.hBeamCals{i});
                end
            end
            obj.hBeamCals = {};
            
            if ~isempty(obj.hBeamsPark)
                delete(obj.hBeamsPark);
            end
            obj.hBeamsPark = [];
        end
        
        function ziniPrepareBeams(obj)
            import dabs.ni.daqmx.*
            try
                tfBeamsFeatureOn = ~isempty(obj.mdfData.beamDeviceName) && ...
                    ~isempty(obj.mdfData.beamChanIDs);
                if ~tfBeamsFeatureOn
                    obj.ziniDisableBeamsFeature();
                    fprintf(1,'No beams device or channels specified in Machine Data File. Feature disabled.\n');
                    return;
                end
                
                % beamChanIDs
                obj.zprvMDFVerify('beamChanIDs',{{'numeric'},{'integer' 'vector' 'nonnegative'}},[]);
                numBeams = length(obj.mdfData.beamChanIDs);
                obj.beamNumBeams = numBeams;
                
                if numBeams==0
                    return;
                end
                
                % beamDeviceName
                obj.zprvMDFVerify('beamDeviceName',{{'char'},{'vector'}},[]);
                
                obj.hDaqDevice = dabs.ni.daqmx.Device(obj.mdfData.beamDeviceName);
                obj.detectPxiChassis(); % check if daq device is part of main PXI chassis and update obj.mdfData.beamModifiedLineClockIn accordingly
                
                obj.zprvMDFVerify('beamModifiedLineClockIn',{{'char'},{'vector','nonempty'}},[]);
                obj.extLineClockTerminal = obj.mdfData.beamModifiedLineClockIn;

                % beamIDs
                if isempty(obj.mdfData.beamIDs)
                    obj.mdfData.beamIDs = arrayfun(@(x)sprintf('Beam %d',x),(1:numBeams)','UniformOutput',false);
                end
                obj.zprvMDFVerify('beamIDs',{},@(x)iscellstr(x)&&numel(x)==numBeams);
                obj.beamIDs = obj.mdfData.beamIDs;
                
                % beamVoltageRanges
                obj.zprvMDFScalarExpand('beamVoltageRanges',numBeams);
                obj.zprvMDFVerify('beamVoltageRanges',{{'numeric'},{'real' 'vector' '>=' 0.0}},@(x)numel(x)==numBeams);
                                
                % shutterBeforeBeam
                obj.zprvMDFVerify('shutterBeforeBeam',{{'numeric' 'logical'},{'binary' 'scalar'}},[]);
                
                % beamCalUseRejectedLight
                obj.zprvMDFScalarExpand('beamCalUseRejectedLight',numBeams);
                obj.zprvMDFVerify('beamCalUseRejectedLight',{{'logical' 'numeric'},{'vector' 'binary'}},[]);
                
                %%% Initialize model props
                obj.beamVoltageRanges = obj.mdfData.beamVoltageRanges;

                %%% Create Beam/BeamCal/BeamPark Tasks
                obj.hBeamCals  = cell(obj.beamNumBeams,1);
                obj.hBeamsTask = obj.zprvDaqmxTask('Beam Modulation');
                obj.hBeamsPark = obj.zprvDaqmxTask('Beam Modulation Park');
                
                for i=1:obj.beamNumBeams
                    idString = obj.mdfData.beamIDs{i};
                    
                    %Create AO chan for beam 'parking' (static AO control)
                    obj.hBeamsPark.createAOVoltageChan(obj.mdfData.beamDeviceName,obj.mdfData.beamChanIDs(i),sprintf('%s Park',idString));
                    
                    %Create AO chans for beam
                    obj.hBeamsTask.createAOVoltageChan(obj.mdfData.beamDeviceName,obj.mdfData.beamChanIDs(i),idString);
                end
                
                % Configure Beam modulation Task
                supportedSampleRate = getMaxSampRate(obj.hBeamsTask,obj.beamNumBeams);
                obj.hBeamsTask.cfgSampClkTiming(supportedSampleRate,'DAQmx_Val_FiniteSamps');
                obj.maxSampleRate = obj.hBeamsTask.sampClkRate; % read back actual sample rate
                obj.hBeamsTask.cfgDigEdgeStartTrig(obj.extLineClockTerminal);                
                obj.hBeamsTask.set('startTrigRetriggerable',true);
                                
            catch ME
                fprintf(2,'Error occurred while initializing ''beams''. Incorrect MachineDataFile settings likely cause. \n Disabling beams feature. \n Error stack: \n');
                most.idioms.reportError(ME);
                obj.ziniDisableBeamsFeature();
            end
            
            function rate = getMaxSampRate(hTask,numChans)
               % workaround for bug in DAQmx 9.8.0f3: 'sampClkMaxRate' reports
               % faster clock rates for multichannel AOs than supported by
               % hardware (observed with PCIe-6321)
               factorMap = containers.Map({0, 1, 2   , 3   , 4   },...
                                          {1, 1, 0.92, 0.85, 0.78});
               reductionFactor = factorMap(numChans);
               rate = hTask.get('sampClkMaxRate') * reductionFactor;
            end
        end
    
        function ziniCalibrateBeams(obj)
            import dabs.ni.daqmx.*
            try
                numBeams = obj.beamNumBeams;
                               
                % beamCalInputChanIDs
                if isempty(obj.mdfData.beamCalInputChanIDs)
                    obj.mdfData.beamCalInputChanIDs = nan(numBeams,1);
                end
                obj.zprvMDFScalarExpand('beamCalInputChanIDs',numBeams);
                obj.zprvMDFVerify('beamCalInputChanIDs',{{'numeric'},{'vector'}},@(x)numel(x)==numBeams);
                
                % beamCalOffsets
                if isempty(obj.mdfData.beamCalOffsets)
                    obj.mdfData.beamCalOffsets = zeros(numBeams,1);
                end
                obj.zprvMDFVerify('beamCalOffsets',{{'numeric'},{'vector'}},@(x)numel(x)==numBeams);

                obj.beamCalibrationLUT = nan(obj.beamCalibrationLUTSize,obj.beamNumBeams);
                obj.beamCalibrationMinCalVoltage = nan(1,obj.beamNumBeams);
                obj.beamCalibrationMaxCalVoltage = nan(1,obj.beamNumBeams);
                obj.beamCalibrationMinAchievablePowerFrac = zeros(1,obj.beamNumBeams);
                obj.beamPowers = ones(1,obj.beamNumBeams);
                obj.beamPzAdjust = zeros(1,obj.beamNumBeams);
                obj.hBeamCals = cell(obj.beamNumBeams,1);

                for i=1:obj.beamNumBeams
                    idString = obj.mdfData.beamIDs{i};

                    %Create AI Task/chan for each beam's calibration
                    beamCalChanID = obj.mdfData.beamCalInputChanIDs(i);
                    if isnan(beamCalChanID)
                        hBeamCal = [];
                    else
                        hBeamCal = obj.zprvDaqmxTask([idString ' Calibration']);
                        hBeamCal.createAIVoltageChan(obj.mdfData.beamDeviceName,beamCalChanID);
                        hBeamCal.set('readReadAllAvailSamp',1); %Paradoxically, this is required for X series AI Tasks to correctly switch between finite acquisitions of varying duration
                    end
                    
                    obj.hBeamCals{i} = hBeamCal;
                end
                
                % Perform calibration
                obj.beamsCalibrate([],true); % showShutterWarning at startup
            catch ME
                fprintf(2,'Error occurred while initializing ''beams''. Incorrect MachineDataFile settings likely cause. \n Disabling beams feature. \n Error stack: \n');
                most.idioms.reportError(ME);
                obj.ziniDisableBeamsFeature();
            end                
        end
    end
    
    %% HIDDEN METHODS (Beam Operations)
    methods (Hidden)
        % AL: I was surprised that this method not only updates the
        % flybackdata but also stops beam, writesOnData, starts beam.
        function zprvBeamsUpdateFlybackBuffer(obj)
            %Updates beamFlybackBlankData and beamFlybackBlankData mask buffers maintained by this class
            %Except when stop/restarting, the beam AO buffer is also updated (i.e. written to)
            %
            %
            % Flyback buffer depends on:
            %   scanFillFraction, scanLinePeriod, scanMode
            %   beamNumBeams, beamFlybackBlanking
            %
            %TODO: If FastZ update is restored in this function, consider providing input argument indicating whether to defer FastZ
            %       update on stopAndRestart, e.g. for prop changes affecting only the FastZBuffer
            
            if obj.beamNumBeams == 0 || ~obj.beamFlybackBlanking
                obj.beamFlybackBlankData = [];
                
                if obj.beamNumBeams == 0
                    return;
                end
            end
            
            linePeriod = obj.scanLinePeriod;
            if isnan(linePeriod)
                linePeriod = obj.scanLinePeriodNearestSmaller;
                if isnan(linePeriod)
                    linePeriod = obj.scanLinePeriodNominal;
                end
            end
            
            if obj.beamFlybackBlanking
                %Determine beam amplitudes during ON and OFF  times
                switch obj.beamPowerUnits
                    case 'percent'
                        beamOffVoltages = obj.beamOffPowerVoltages(:)';
                        beamOnVoltages = obj.beamOnPowerVoltages(:)';
                    otherwise
                        assert('Only percent-mode power values presently supported');
                end
                
                onNumSamples = ceil(obj.maxSampleRate * linePeriod);
                outData = [ones(onNumSamples,1)*beamOnVoltages;beamOffVoltages];
                
                obj.beamFlybackBlankData = outData;
                obj.beamFlybackBlankDataMask = [ones(onNumSamples,1);0];
            end
            
            %Update data in output buffer
            if strcmpi(obj.acqState,'focus')
                %TODO: Selectively restart only those beams used for Focus
                obj.hBeamsTask.stop();
                obj.zprvBeamsWriteFlybackData();
                obj.hBeamsTask.start();
            else
                obj.zprvBeamsWriteFlybackData();
            end
            %TODO: Consider whether to update (pre-compute) FastZ buffer here and in what circumstances. For now, leaving out.
        end
        
        function zprvBeamsWriteFlybackData(obj)
            if obj.beamNumBeams > 0
                if obj.beamFlybackBlanking
                    outData = obj.beamFlybackBlankData;
                else
                    % Just write a single sample (twice) -- the same value is used throughout
                    % each entire line period, so no long buffer is needed
                    outData = repmat(obj.beamOnPowerVoltages(:)',2,1);
                end
                
                %Ensure even number of samples
                if mod(size(outData,1),2) == 1
                    outData(end+1,:) = outData(end,:);
                end
                
                obj.hBeamsTask.abort();
                obj.beamsOff();
                obj.hBeamsTask.reset('writeRelativeTo');
                obj.hBeamsTask.reset('writeOffset');
                obj.hBeamsTask.control('DAQmx_Val_Task_Unreserve'); %should flush data
                
                obj.hBeamsTask.cfgOutputBuffer(size(outData,1));
                
                obj.hBeamsTask.set('startTrigRetriggerable',true);
                obj.hBeamsTask.cfgDigEdgeStartTrig(obj.extLineClockTerminal);                
                obj.hBeamsTask.cfgSampClkTiming(obj.maxSampleRate,'DAQmx_Val_FiniteSamps',size(outData,1));
                obj.hBeamsTask.writeAnalogData(outData);
            end
        end
        
        function zprvBeamsWriteFastZData(obj)
            % Compute and write FastZ buffer to beam Task, containing beam flyback/power waveforms for entire volume period
            %
            % NOTES
            %   Function computes and writes FastZ buffer to Task frame-wise, avoiding creation of large memory buffer
            %
            %   TODO: Handle correctly the FastZ buffer case when flyback blanking is disabled
            
            if obj.beamNumBeams == 0
                return;
            end
            
            %Compute 'base' data for one period, using current power specification
            if obj.beamFlybackBlanking
                scanPeriodBase = repmat(obj.beamFlybackBlankDataMask,1,obj.beamNumBeams); %Data mask for one period
            else
                scanPeriodBase = ones(length(obj.beamFlybackBlankDataMask),obj.beamNumBeams);
            end
            periodLength = size(scanPeriodBase,1);
            
            %%Prepare beam Task for FastZ buffer
%             switch obj.scanMode
%                 case 'unidirectional'
                     periodsPerFrame = obj.linesPerFrame;
%                 case 'bidirectional'
%                     periodsPerFrame = obj.linesPerFrame / 2;
%             end
            %samplesPerFrame = periodLength * periodsPerFrame;
            %!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            %TODO:Make this work with SI5, as these are dependent props
            %from SI5.m
            %!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            if isinf(obj.acqNumFramesPerTrigger)
                framesPerVolume = obj.fastZNumFramesPerVolume;
            else
                framesPerVolume = obj.acqNumFramesPerTrigger / obj.fastZNumVolumes;
            end
            %!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            obj.hBeamsTask.control('DAQmx_Val_Task_Unreserve');
            obj.hBeamsTask.cfgSampClkTiming(obj.maxSampleRate,'DAQmx_Val_FiniteSamps',periodLength);
            
            volumeBufferLength = periodLength * periodsPerFrame * framesPerVolume;
            if obj.fastZAllowLiveBeamAdjust
                obj.hBeamsTask.cfgOutputBuffer((obj.fastZBeamNumBufferedVolumes + 1) * volumeBufferLength);
            else
                obj.hBeamsTask.cfgOutputBuffer(volumeBufferLength);
            end
            
            %Determine starting position and step-size
            stepsPerVolume = framesPerVolume - obj.fastZNumDiscardFrames;
            stepSize = obj.stackZStepSize;
            stackSize = (stepsPerVolume - 1) * stepSize;
            
            currPosn  = -stepSize/2; %Shift to align start power with center of first or middle stack slice
            
            if obj.stackStartCentered %Shift to align starting power with middle stack slice
                currPosn = currPosn - stackSize/2;
            end
            
            %Compute FastZ buffer, frame-at-a-time, and write to AO Task
            if obj.fastZAllowLiveBeamAdjust
                obj.fastZBeamDataBuf = zeros(volumeBufferLength,1);
                startIdx = 1;
                numBufVolumes = obj.fastZBeamNumBufferedVolumes;
                
            else
                numBufVolumes = 1;
            end
            
            framePosns = repmat(linspace(currPosn,currPosn+stepSize,periodLength*periodsPerFrame)',1,obj.beamNumBeams);
            lengthConstants = repmat(obj.acqBeamLengthConstants',periodLength*periodsPerFrame,1);
            
            scanPeriodBase(isnan(scanPeriodBase(:,1)),:) = 0;
            scanPeriods = repmat(scanPeriodBase,periodsPerFrame,1);
            
            for i = 1:numBufVolumes
                for j = 1:stepsPerVolume
                    beamPowerFactors = exp(framePosns./lengthConstants);
                    framePosns = framePosns + stepSize;
                    
                    dataToAppend = scanPeriods;
                    for k=obj.beamNumBeams:-1:1
                        dataToAppend(:,k) = dataToAppend(:,k) .* obj.zprpBeamsPowerFractionToVoltage(k,obj.beamPowers(:,k) .* beamPowerFactors(:,k) / 100.0);
                    end
                    obj.hBeamsTask.writeAnalogData(dataToAppend);
                    
                    if obj.fastZAllowLiveBeamAdjust && i==1
                        endIdx = startIdx + length(dataToAppend) - 1;
                        obj.fastZBeamDataBuf(startIdx:endIdx) = dataToAppend;
                        startIdx = endIdx + 1;
                    end
                end
            end
            
            for j = 1:obj.fastZNumDiscardFrames
                dataToAppend = scanPeriods;
                for k=obj.beamNumBeams:-1:1
                    dataToAppend(:,k) = obj.beamOffPowerVoltages(k);
                end
                obj.hBeamsTask.writeAnalogData(dataToAppend);
            end
            
            %Initialize FastZ beam live adjustability, if needed
            if obj.fastZAllowLiveBeamAdjust
                obj.fastZBeamPowersCache = obj.beamPowers;
                obj.fastZBeamWriteOffset = size(obj.fastZBeamDataBuf * obj.fastZBeamNumBufferedVolumes,1);
            else
                obj.fastZBeamPowersCache = [];
                obj.fastZBeamWriteOffset = [];
            end
            
        end
        
        function zprvBeamsRefreshFastZData(obj,numFrames)
            %Refresh FastZ beam data according to current power levels, as required when fastZAllowLiveBeamAdjust=true
            
            obj.hBeamsTask.set('writeOffset',obj.fastZBeamWriteOffset);
            
            bufLen = size(obj.fastZBeamDataBuf,1); %Length of entire volume
            if isinf(numFrames)
                indices = 1:bufLen;
            else
                samplesPerFrame = bufLen / obj.fastZNumFramesPerVolume; %Should evenly divide
                
                frameIdx = rem(obj.fastZBeamWriteOffset,bufLen)/ samplesPerFrame; %zero-based frame index
                
                indices = (1:(numFrames * samplesPerFrame)) + frameIdx * samplesPerFrame;
            end
            
            if obj.beamNumBeams == 1

                obj.hBeamsTask.writeAnalogData(obj.fastZBeamDataBuf(indices,:) * (obj.beamPowers/obj.fastZBeamPowersCache));
            else
                
                obj.hBeamsTask.writeAnalogData(obj.fastZBeamDataBuf(indices,:) .* repmat(obj.beamPowers./obj.fastZBeamPowersCache,length(indices),1)); %
            end
            %fprintf('Wrote %d samples at offset %d in %g ms\n',length(indices),obj.fastZBeamWriteOffset,toc()*1000);
            obj.fastZBeamWriteOffset = obj.fastZBeamWriteOffset + length(indices);
            
        end
        
        function [tfSuccess beamCalVoltage beamVoltage] = zprvBeamsGetCalibrationData(obj,beamIdx)
            % tfSuccess: true if calibration successful.
            % beamCalVoltage: (beamCalibrationNumVoltageSteps x
            % beamCalibrationNumPasses) vector of beam cal voltages
            % corresponding to beamVoltage
            % beamVoltage: (beamCalibrationNumVoltageSteps x 1) vector of beam
            % voltages
            
            validateattributes(beamIdx,{'numeric'},{'vector','integer','>=',1,'<=',obj.beamNumBeams});
            
            wb = waitbar(0,sprintf('Calibrating beam %d...', beamIdx),...
                'Name','Calibrating...','CreateCancelBtn','hSI.beamCancelCalibration = true;');
            
            voltageRange = obj.beamVoltageRanges(beamIdx);
            
            %Create array of modulation voltages
            % Add zeros at the end b/c "VI111010A: Add delay between
            % calibration sweeps (allows for case where slow decay in
            % transmission is seen after reaching high voltages) -- Vijay
            % Iyer 11/10/10"
            %
            % Hold each voltage step for 2 samples. We'll record input signal on 2'nd of each pair, to avoid any settling time problems.
            %
            
            voltageSteps = linspace(0,voltageRange,obj.beamCalibrationNumVoltageSteps);
            beamVoltage = [zeros(1,2*numel(voltageSteps))  zeros(1,obj.beamCalibrationIntercalibrationZeros)]';
            for i=1:numel(voltageSteps)
                [beamVoltage(2*i-1) beamVoltage(2*i)] = deal(voltageSteps(i));
            end
            NbeamVoltage = numel(beamVoltage);
            
            %             assert(rem(NbeamVoltage,2)==0,...
            %                 'Input buffer length must be even, to avoid DAQmx error -200692 with some devices (e.g. AO series)');
            %             % Assert from note by Vijay Iyer, 11/24/10
            
            % TODO old code set other beams to output zero during calibration.
            % is this necessary?
            
            
            if isempty(obj.hBeamCals{beamIdx})
                tfSuccess = true;
                beamCalVoltage = [];
                znstCleanup(false);
                return;
            end
            
            %Prepare hBeams and hBeamCals
            %beamTask = obj.hBeamsTask(beamIdx);
            beamTask = obj.hBeamsTask;
            assert(isscalar(beamTask));
            beamTask.control('DAQmx_Val_Task_Unreserve');
            beamTask.cfgSampClkTiming(obj.beamCalibrationOutputRate,'DAQmx_Val_FiniteSamps',NbeamVoltage);
            beamTask.cfgOutputBuffer(NbeamVoltage);
            beamTask.set('startTrigRetriggerable',false);
            beamTask.disableStartTrig();
            beamVoltageAllChan = zeros(numel(beamVoltage),obj.beamNumBeams);
            beamVoltageAllChan(:,beamIdx) = beamVoltage;
            beamTask.writeAnalogData(beamVoltageAllChan);
            
            beamCalTask = obj.hBeamCals{beamIdx};
            beamCalTask.set('startTrigRetriggerable',false);
            beamCalTask.disableStartTrig();
            beamCalTask.control('DAQmx_Val_Task_Unreserve');
            beamCalTask.cfgSampClkTiming(obj.beamCalibrationOutputRate,'DAQmx_Val_FiniteSamps',NbeamVoltage,beamTask.get('sampClkTerm'));
            
            % calibration loop
            beamCalVoltage = zeros(NbeamVoltage,obj.beamCalibrationNumPasses);
            calibrationPassTime = NbeamVoltage / obj.beamCalibrationOutputRate;
            
            tfSuccess = false;
            try % Why is this try/catch necessary?
                for c = 1:obj.beamCalibrationNumPasses
                    if obj.beamCancelCalibration
                        znstCancelCleanup();
                        return;
                    end
                    
                    beamCalTask.start();
                    beamTask.start();
                    
                    beamCalVoltage(:,c) = beamCalTask.readAnalogData(NbeamVoltage);
                    
                    beamTask.stop();
                    beamCalTask.stop();
                    pause(obj.beamCalibrationIntercalibrationPauseTime);
                    waitbar(c/obj.beamCalibrationNumPasses,wb);
                end
            catch ME %#ok<NASGU>
                %Some error occurred during calibration, most likely while reading calibration data.
                %Leave to caller to generate warning/error message (since tfSuccess=false)
                znstCleanup();
                return;
                %rethrow(ME);
            end
            
            if obj.beamCancelCalibration
                znstCancelCleanup();
                return;
            end
            
            znstCleanup();
            tfSuccess = true;
            
            function znstCleanup(beamCalibrated)
                
                if nargin < 1
                    beamCalibrated = true;
                end
                
                delete(wb);
                
                %Remove intercalibration zeros
                numZeros = obj.beamCalibrationIntercalibrationZeros;                
                beamVoltage(end-numZeros+1:end) = [];
                if beamCalibrated
                    beamCalVoltage(end-numZeros+1:end,:) = [];
                end                    
                
                %Take second of every pair of beamVoltage/beamCalVoltage values (first sample was for settling)
                beamVoltage = beamVoltage(2:2:end);
                if beamCalibrated
                    beamCalVoltage = beamCalVoltage(2:2:end,:);
                end
                                
                if beamCalibrated
                    %Clean up Beam DAQ Tasks
                    beamTask.stop();
                    beamCalTask.stop();
                    beamTask.control('DAQmx_Val_Task_Unreserve');
                    beamCalTask.control('DAQmx_Val_Task_Unreserve');
                    
                    %Restore beam Task's calibration (perhaps via cache-and-restore, rather than hard-coded revert to initialized state)
                    obj.hBeamsTask.set('startTrigRetriggerable',true);
                    obj.hBeamsTask.cfgDigEdgeStartTrig(obj.extLineClockTerminal);
                    %beamTask.set('pauseTrigType','DAQmx_Val_DigLvl');                    
                end
                
                
            end
            
            function znstCancelCleanup()
                znstCleanup();
                obj.beamCancelCalibration = false;
            end
        end
        
        function [lut beamCalMinVoltage beamCalMaxVoltage] = zprvBeamsProcessCalibrationData(obj,beamVoltage,beamCalVoltage,beamCalOffset,rejectedLight)
            % lut: (beamCalibrationLUTSize x 1) numeric array, where lut(i)
            % gives beam voltage necessary to achieve
            % (i/beamCalibrationLUTSize) fraction of maximum achieved power
            % beamCalMin/MaxVoltage: min/max beam cal voltage (averaged over
            % calibration passes) achieved during calibration sweeps
            % rejectedLight: true if rejected light is employed for calibration
            
            assert(isvector(beamVoltage) && size(beamCalVoltage,1)==numel(beamVoltage));
            
            bcv_mu = mean(beamCalVoltage,2);
            bcv_mu = bcv_mu - beamCalOffset;
            bcv_mu_raw = bcv_mu; %Store 'raw' value in case we need to display it later (for failed calibrations)
            
            bcv_sd = std(beamCalVoltage,1,2); % Old veej notes: Normalize by the number of calibration passes?
            bcv_mu(bcv_mu<0) = 0; %Identify negative values (likely due to incorrect offset) as 0 TODO: Better way?
            
            
            beamCalMinVoltage = min(bcv_mu);
            beamCalMaxVoltage = max(bcv_mu);
            
            bcvNormalized = bcv_mu/beamCalMaxVoltage;
                
            % Take measurement from rejected light, if necessary.
            % TODO: Handle per-beam           
            if rejectedLight
                bcvNormalized = 1 - bcvNormalized;
                bcvNormalized = bcvNormalized/max(bcvNormalized); %Renormalize to ensure max value = 1.0
            end
            
            [~,minIdx] = min(bcvNormalized);
            [~,maxIdx] = max(bcvNormalized);
            
            avg_dev = mean(bcv_sd/beamCalMaxVoltage);
            minAchievableBeamPowerFraction = max(beamCalMinVoltage/beamCalMaxVoltage, 1/obj.beamCalibrationLUTSize) ; %Enforce maximum dynamic range supported by LUT size 
            
            % warnings/failures
            tfFatalFailure = false;
            
            
            if avg_dev > obj.beamCalibrationFluctuationThreshold
                if beamCalMaxVoltage == 0
                    tfFatalFailure = true;
                    fatalWarnStr = 'Beam calibration data appears entirely negative-valued, unexpectedly. Connections or hardware may be faulty.';
                else
                    warning('SI5:zprvBeamsProcessCalibrationData',...
                        'Beam calibration seems excessively noisy. Typical standard deviation per sample: %s%%.',...
                        num2str(100*avg_dev));
                    obj.zprvBeamsShowRawCalibrationData(beamVoltage, bcv_mu_raw);
                    % Continue with regular calibration
                end
            end
            
            if minAchievableBeamPowerFraction > obj.beamCalibrationMinThreshold
                tfFatalFailure = true;
                fatalWarnStr = sprintf('Beam calibration minimum power not less than 15%% of maximum power. Min/max: %s%%',...
                    num2str(100*minAchievableBeamPowerFraction));
            end
            if beamCalMaxVoltage > 0 &&  minIdx >= maxIdx
                tfFatalFailure = true;
                fatalWarnStr = '';
            end
            if tfFatalFailure
                znstWarnAndRunNaiveCalibration(fatalWarnStr);
                return;
            end            
   
            
            lut = zeros(obj.beamCalibrationLUTSize,1);
            
        
            
            minAchievableBeamPowerLUTIdx = ceil(minAchievableBeamPowerFraction * obj.beamCalibrationLUTSize);
            %             if minAchievableBeamPowerLUTIdx==0
            %                 minAchievableBeamPowerLUTIdx = 1;
            %             end
            
            lut(1:minAchievableBeamPowerLUTIdx-1) = nan; % These beam power idxs are unachievable; their lut values should never be used
            % For rest of LUT, do interpolation over interval [minIdx,maxIdx]
            
            x = bcvNormalized(minIdx:maxIdx);
            y = beamVoltage(minIdx:maxIdx);
            
            % eliminate any flat zeros at beginning (these can be generated since we set all bcvNormalized values less than 0 to be 0)
            tfFlatZero = x==0;
            if any(tfFlatZero)
                flatZeroIdx = find(tfFlatZero);
                if ~isequal(flatZeroIdx,(1:numel(flatZeroIdx))')
                    % expect flat zeros only at the beginning
                    znstWarnAndRunNaiveCalibration('Unexpected flat zeros in beam calibration voltage');
                    return;
                end
                x(flatZeroIdx(1:end-1)) = []; % take last flatzero datapoint (highest beam voltage)
                y(flatZeroIdx(1:end-1)) = [];
            end
            
            x = zlclMonotonicize(x);
            y = zlclMonotonicize(y);
            
            % Check to see if any values in x are repeated. If there are any repeated values in x, then interp1 will fail, so run a naive calibration.
            if numel(unique(x)) == numel(x)
                lut(minAchievableBeamPowerLUTIdx:obj.beamCalibrationLUTSize) = interp1(x,y,(minAchievableBeamPowerLUTIdx:obj.beamCalibrationLUTSize)/obj.beamCalibrationLUTSize,'pchip',nan);
            else
                znstWarnAndRunNaiveCalibration('Repeated Values Found in Beam Calibration Data.');
            end
            
            function znstWarnAndRunNaiveCalibration(warnMsg)
                fprintf(2,'\nWARNING: Beam calibration data appears suspect. Using naive calibration.\n');
                if ~isempty(warnMsg)
                    fprintf(2,'\n Explanation: %s\n',warnMsg);
                end
                obj.zprvBeamsShowRawCalibrationData(beamVoltage,bcv_mu_raw);
                [lut beamCalMinVoltage beamCalMaxVoltage] = ...
                    obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
            end
        end
        
        function [lut beamCalMinVoltage beamCalMaxVoltage] = zprvBeamsPerformNaiveCalibration(obj,beamVoltage,rejectedLight)            
           
            if rejectedLight
                calVoltage = max(beamVoltage) - beamVoltage;
            else
                calVoltage = beamVoltage;
            end
            
            [lut beamCalMinVoltage beamCalMaxVoltage] = obj.zprvBeamsProcessCalibrationData(beamVoltage,calVoltage,0.0,rejectedLight);
        end
        
        function zprvBeamsSetCalibrationInfo(obj,beamIdx,lut,beamCalMinVoltage,beamCalMaxVoltage)
            validateattributes(beamIdx,{'numeric'},{'vector','integer','>=',1,'<=',obj.beamNumBeams});
            validateattributes(lut,{'numeric'},{'size',[obj.beamCalibrationLUTSize 1]});
            
            obj.beamCalibrationLUT(:,beamIdx) = lut;
            obj.beamCalibrationMinCalVoltage(1,beamIdx) = beamCalMinVoltage;
            obj.beamCalibrationMaxCalVoltage(1,beamIdx) = beamCalMaxVoltage;
            
            % round this value to the "resolution" of the LUT
            obj.beamCalibrationMinAchievablePowerFrac(1,beamIdx) = ...
                ceil(beamCalMinVoltage/beamCalMaxVoltage*obj.beamCalibrationLUTSize)/obj.beamCalibrationLUTSize;
            
            obj.beamPowers = obj.zprvBeamEnforcePowerLimits(obj.beamPowers);
        end
        
        function zprvBeamsShowRawCalibrationData(obj,beamVoltages,beamCalVoltages) %#ok<MANU>
            %Displays figure showing last measured raw calibration data obtained for beam modulation device of specified beamIdx
            
            f = figure('NumberTitle','off','DoubleBuffer','On','Name','Beam Calibration Curve','Color','White');
            a = axes('Parent',f,'FontSize',12,'FontWeight','Bold');
            [beamVoltages,idxs] = sort(beamVoltages);
            plot(beamVoltages,beamCalVoltages(idxs),'Parent',a,'Color',[0 0 0],'LineWidth',2);
            title(sprintf('Raw Calibration Data'),'Parent',a,'FontWeight','bold');
            xlabel('Beam Modulation Voltage [V]','Parent',a,'FontWeight','bold');
            ylabel('Beam Calibration Voltage [V]','Parent',a,'FontWeight','bold');
            %TODO is this figHandle stored somewhere
        end
        
        function zprvBeamsDepthPowerCorrection(obj,zStepSize,lz)
            % Modifies ith beam power according to
            %   newPower(i) = oldPower(i)*exp(zStepSize/lz(i))
            if obj.beamNumBeams > 0
                assert(numel(lz)==obj.beamNumBeams);
                obj.zprvSetInternal('beamPowers', obj.beamPowersNominal.*exp(zStepSize./lz'));                
                %obj.zprvSetBeamPowers(obj.beamPowersNominal.*exp(zStepSize./lz));
            end
        end
        
        function beamPowers = zprvBeamEnforcePowerLimits(obj,beamPowers)
            assert(numel(beamPowers)==obj.beamNumBeams);
            
            % enforce upper limit
            maxPowers = obj.beamPowerLimits;
            switch obj.beamPowerUnits
                case 'percent'
                    beamPowers = min(beamPowers,maxPowers);
                case 'milliwatts'
                    % TODO
            end
            
            % enforce lower limit
            for c = 1:obj.beamNumBeams
                switch obj.beamPowerUnits
                    case 'percent'
                        beamPowers(c) = max(beamPowers(c),obj.beamCalibrationMinAchievablePowerFrac(c)*100);
                    case 'milliwatts'
                        %TODO
                end
            end
        end
        
        function inPxiChassis = detectPxiChassis(obj)
            inPxiChassis = false;
            if isempty(obj.hModel) || ~isvalid(obj.hModel)
                 % adapter is not called from SI5.m PXI routing is not available
                 return
            end
            
            inPxiChassis = obj.hModel.hTriggerMatrix.isDeviceInMainPxiChassis(obj.mdfData.beamDeviceName);
            if inPxiChassis
                obj.mdfData.beamModifiedLineClockIn = obj.hModel.hTriggerMatrix.PXI_TRIGGER_MAP('beamModifiedLineClock');
                fprintf('Beams: Set beamModifiedLineClock to ''%s''\n',obj.mdfData.beamModifiedLineClockIn);
            end
        end
    end
    
    %% HIDDEN METHODS (Misc)
    methods (Hidden)
        function tf = isIdle(obj)
            tf = strcmpi(obj.acqState,'idle');
        end
        
        function zprvSetInternal(obj,propName,val)
            isf  = obj.internalSetFlag;
            obj.internalSetFlag = true;
            ME = [];
            try
                obj.(propName) = val;
            catch MEtemp
                ME = MEtemp;
            end
            obj.internalSetFlag = isf;
            
            if ~isempty(ME)
                ME.rethrow();
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
        
        function zprvMDFScalarExpand(obj,mdfVarName,N)
            if isscalar(obj.mdfData.(mdfVarName))
                obj.mdfData.(mdfVarName) = repmat(obj.mdfData.(mdfVarName),N,1);
            end
        end
        
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
        
        function zprvResetHome(obj)
            %Reset home beam position
            obj.acqBeamPowersStackStart = [];
        end
        
        function zprvSetHome(obj)
            %Reset home beam position
            obj.acqBeamPowersStackStart = obj.beamPowers;
        end
        
        function zprvGoHome(obj)
            %Go to home motor/fastZ/beam positions/powers, as applicable
            if ~isempty(obj.acqBeamPowersStackStart)
                obj.zprvSetInternal('beamPowers', obj.acqBeamPowersStackStart);
            end
        end
        
        function hTask = zprvDaqmxTask(obj,taskName)
            %import dabs.ni.daqmx.*
            
            hTask = scanimage.util.priv.safeCreateTask(taskName);   %HACK         
        end
        
        function zcbkParentUpdated(obj,src,evnt)            
           propName = src.Name;
           hParent = evnt.AffectedObject;
           
           obj.(propName) = hParent.(propName);
        end
        
    end
    
    
end

%% LOCAL FUNCTIONS
% VI: Sometimes a quite-clean calibration will fail this test -- we
% should probably prevent warning in this case. Perhaps warning is never
% needed anymore?
% AL: Clean runs should not fail this test anymore. Is nonmonotonicity a
% failure condition?
function x = zlclMonotonicize(x)
assert(isnumeric(x)&&isvector(x));
d = diff(x);
if any(d<=0)
    warning('SI4:zlclMonotonicize','Vector not monotonically increasing.');
end
end

function zlclAddQuantityAnnotations(ax,xPos,yPos,lbls,qtys,varargin)
axes(ax); %#ok<MAXES>

for c = 1:numel(lbls)
    h = text(xPos,yPos,sprintf('%s: ',lbls{c}),'HorizontalAlignment','right',varargin{:});
    qty = qtys{c};
    if isnumeric(qty)
        formatStr = '%.2f';
    else
        formatStr = '%s';
    end
    text(xPos,yPos,sprintf(formatStr,qty),'HorizontalAlignment','left',varargin{:});
    ext = get(h,'Extent');
    dyPos = ext(end);
    yPos = yPos - dyPos;
end

end

%--------------------------------------------------------------------------%
% Beams.m                                                                  %
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
