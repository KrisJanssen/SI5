classdef Motors < most.MachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Motors';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %% PUBLIC PROPS
    properties (SetObservable)
        hMotor;% Warning: It is dangerous to directly zero or modify the relative coordinate system on the motor. This will break stackZStart/EndPos. See motorZeroSoft().
        hMotorZ; % etc
        
        motorDimensionConfiguration; % one of {'none' 'xy' 'z' 'xyz'} when there is a single motor; one of {'xy-z' 'xyz-z'} when there are two motors
        
        motorSecondMotorZEnable = false; % scalar logical. If true, use second motor for stack z-movement. This flag is only interesting when motorDimensionConfiguration is 'xyz-z'. (For other motorDimensionConfigurations, the value of this flag is constrained to a single value.)
        
        mdlInitialized = false;
        
        motorPosition; % 1x3 or 1x4 array specifying motor position (in microns), depending on single vs dual motor, and motorDimensionConfiguration.
        motorPositionLength; %Length of motorPosition values
        motorHasMotor; % true if there is a motor
        motorHasSecondMotor; % true if there is a secondary motor. cannot be true if motorHasMotor is false
        
        acqState='idle'; %One of {'idle' 'focus' 'grab' 'loop' 'loop_wait' 'point'}
        
        %Function callbacks
        hErrorCallBack; %Function handle for Motor Error (should be set by SI5.m)
    end
    
    %% TRANSIENT PROPS
    properties (Transient,SetObservable)
        motorMoveTimeout = 5; %Maximum time, in seconds, to allow for stage moves. %TODO: Ideally could anticipate
        motorFastMotionThreshold = 100; %Distance, in um, above which motion will use the 'fast' velocity for controller
        motorUserDefinedPositions = cell(0,1); % Col vec of user-defined motor positions (which are 1x3 vecs)
        
        %stackZStartPos=nan; %z-position from Motor::stack panel; does NOT apply to all acqs. This position is _relative to hMotor's relative origin_. It is _not_ in absolute coords.
        %stackZEndPos=nan; %z-position from Motor::stack panel; does NOT apply to all acqs. This position is _relative to hMotor's relative origin_. It is _not_ in absolute coords.        
    end
    
    %% INTERNAL PROPS
    properties (Hidden)
        acqMotorPositionStackStart; %Motor position at last start of stack
        overrideFocusIdleAssertion = false; 
    end
    
    properties (Hidden,SetAccess=protected)
        hModel;
        
        %acqMotorPositionStackStart; %Motor position at last start of stack
        stackCurrentMotorZPos; %z-position of stackZMotor
        stackZMotor; %handle to motor user for stack z-positioning during acq
        
        internalSetFlag = false;
    end
    
    %% LIFECYCLE
    methods
        function obj = Motors(hModel)
            if nargin < 1 || isempty(hModel)
                hModel = [];
            end
            obj.hModel = hModel;
            
            obj.ziniPrepareMotor();
        end
        
        function delete(obj)
            if isobject(obj.hMotor)
                if isvalid(obj.hMotor)
                    delete(obj.hMotor);
                end
            end
            
            if isobject(obj.hMotorZ)
                if isvalid(obj.hMotorZ)
                    delete(obj.hMotorZ);
                end
            end
        end
    end
    
    %% PUBLIC METHODS (Motor Operations)
    methods
        function motorZeroXYZ(obj)
            %Set motor relative origin to current position for X,Y,and Z coordinates.
            
            switch obj.motorDimensionConfiguration
                case 'xy'
                    obj.motorZeroSoft(logical([1 1 0]));
                case 'z'
                    obj.motorZeroSoft(logical([0 0 1]));
                case 'xyz'
                    obj.motorZeroSoft(logical([1 1 1]));
                case 'xy-z'
                    obj.motorZeroSoft(logical([1 1 1]));
                case 'xyz-z'
                    obj.motorZeroSoft(logical([1 1 1 0])); %Do not zero secondary-Z; require motorZeroZ() to do this, with motorSecondMotorZEnable=true
            end
        end
        
        function motorZeroXY(obj)
            %Set motor relative origin to current position for X&Y coordinates.
            
            switch obj.motorDimensionConfiguration
                case 'xy'
                    obj.motorZeroSoft(logical([1 1 0]));
                case 'z'
                    % none
                case 'xyz'
                    obj.motorZeroSoft(logical([1 1 0]));
                case 'xy-z'
                    obj.motorZeroSoft(logical([1 1 0]));
                case 'xyz-z'
                    obj.motorZeroSoft(logical([1 1 0 0]));
            end
        end
        
        function motorZeroZ(obj)
            %Set motor relative origin to current position for Z
            %coordinates. Honor motorSecondMotorZEnable property, if
            %applicable.
            
            switch obj.motorDimensionConfiguration
                case 'xy'
                    % none
                case 'z'
                    obj.motorZeroSoft(logical([0 0 1]));
                case 'xyz'
                    obj.motorZeroSoft(logical([0 0 1]));
                case 'xy-z'
                    obj.motorZeroSoft(logical([0 0 1]));
                case 'xyz-z'
                    if obj.motorSecondMotorZEnable
                        obj.motorZeroSoft(logical([0 0 0 1]));
                    else
                        obj.motorZeroSoft(logical([0 0 1 0]));
                    end
                    
            end
        end
        
        % motorDefineUserPosition(obj,idx,posn) -- set idx'th
        % user-defined position to posn.
        function motorDefineUserPosition(obj,idx,posn)
            % Add current motor position, or specified posn, to
            % motorUserDefinedPositions array at specified idx
            
            validateattributes(idx,{'numeric'},{'scalar' 'integer' 'positive'});
            if nargin==2
                posn = obj.motorPosition;
            end
            obj.motorUserDefinedPositions{idx,1} = posn;
        end
        
        % Clears all user-defined positions
        function motorClearUserDefinedPositions(obj)
            %Clear motorUserDefinedPositions array
            obj.motorUserDefinedPositions = cell(0,1);
        end
        
        function motorGotoUserDefinedPosition(obj,posnIdx)
            %Move motor to position coordinates stored at specified posnIdx in motorUserDefinedPositions array
            
            udp = obj.motorUserDefinedPositions;
            if posnIdx > numel(udp)
                warning('SI5:motorGotoUserDefinedPosition',...
                    'Position index %d exceeds number of user-defined positions. Motor position unchanged.',posnIdx);
                return;
            end
            
            posn = udp{posnIdx};
            if isempty(posn)
                warning('SI5:motorGotoUserDefinedPosition',...
                    'Position index %d is not defined. Motor position unchanged.',posnIdx);
            else
                % nans in user-defined position vecs mean "don't affect this position component"
                tfNan = isnan(posn);
                currPosn = obj.motorPosition;
                posn(tfNan) = currPosn(tfNan);
                obj.zprvSetInternal('motorPosition', posn);
            end
        end
        
        function motorSaveUserDefinedPositions(obj)
            %Save contents of motorUserDefinedPositions array to a position (.POS) file
            
            [fname, pname]=uiputfile('*.pos', 'Choose position list file'); % TODO starting path
            if ~isnumeric(fname)
                periods=strfind(fname, '.');
                if any(periods)
                    fname=fname(1:periods(1)-1);
                end
                s.positionVectors = obj.motorUserDefinedPositions; %#ok<STRNU>
                save(fullfile(pname, [fname '.pos']),'-struct','s','-mat');
                % TODO setStatusString('...')
            end
        end
        
        function motorLoadUserDefinedPositions(obj)
            %Load contents of a position (.POS) file to the motorUserDefinedPositions array (overwriting any previous contents)
            
            [fname, pname]=uigetfile('*.pos', 'Choose position list file');
            if ~isnumeric(fname)
                periods=strfind(fname,'.');
                if any(periods)
                    fname=fname(1:periods(1)-1);
                end
                s = load(fullfile(pname, [fname '.pos']), '-mat');
                obj.motorUserDefinedPositions = s.positionVectors;
                
                % TODO
                % setStatusString('Position list loaded...');
            end
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        
        %% SI4.2 PROPERTY ACCESS METHODS
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
        
        %% MOTOR SPECIFIC PROPERTY ACCESS METHODS
        
        function val = get.motorPosition(obj)
            if ~obj.motorHasMotor
                val = [];
            else
                val = obj.hMotor.positionRelative;
                if obj.motorHasSecondMotor
                    secZPos = obj.hMotorZ.positionRelative(3);
                    switch obj.motorDimensionConfiguration
                        case 'xy-z'
                            val(3) = secZPos;
                        case 'xyz-z'
                            val(4) = secZPos;
                        otherwise
                            assert(false,'Impossible value of motorDimensionconfiguration');
                    end
                end
            end
        end
        
        function val = get.motorPositionLength(obj)
            if ~obj.motorHasMotor
                val = 0;
            elseif ~obj.motorHasSecondMotor || strcmpi(obj.motorDimensionConfiguration,'xy-z')
                val = 3;
            else
                val = 4;
            end
        end
        
        function val = get.motorHasMotor(obj)
            val = ~isempty(obj.hMotor);
        end
        
        function set.motorHasMotor(obj,val)
            obj.motorHasMotor = val;
        end
        
        function val = get.motorHasSecondMotor(obj)
            val = ~isempty(obj.hMotorZ);
        end
        
        function set.acqMotorPositionStackStart(obj,val)
            obj.acqMotorPositionStackStart = val;
        end
        
        function val = get.acqMotorPositionStackStart(obj)
            val = obj.acqMotorPositionStackStart;
        end
        
        function set.motorMoveTimeout(obj,val)
            obj.zprvAssertIdle('motorMoveTimeout');
            val = obj.validatePropArg('motorMoveTimeout',val);
            
            %Currently a single SI5 moveTimeout property controls the
            %primary and secondary motor move and async-move timeout values
            obj.zprvMotorPropSet('nonblockingMoveTimeout',val);
            obj.zprvMotorPropSet('moveTimeout',val);
            if obj.motorHasSecondMotor
                obj.zprvMotorZPropSet('nonblockingMoveTimeout',val);
                obj.zprvMotorZPropSet('moveTimeout',val);
            end
            obj.motorMoveTimeout = val;
        end
        
        function set.motorFastMotionThreshold(obj,val)
            obj.zprvAssertIdle('motorFastMotionThreshold');
            val = obj.validatePropArg('motorFastMotionThreshold',val);
            obj.zprvMotorPropSet('twoStepDistanceThreshold',val);
            obj.motorFastMotionThreshold = val;
        end
        
        function set.motorSecondMotorZEnable(obj,val)
            if ~obj.motorHasMotor
                %obj.zprvMotorThrowNoMotorWarning;
                %disp('No motor is configured')
                return;
            end
            
            obj.zprvAssertFocusOrIdle('motorSecondMotorZEnable');
            obj.validatePropArg('motorSecondMotorZEnable',val);
            mdc = obj.motorDimensionConfiguration;
            switch mdc
                case {'xyz' 'xy' 'z'}
                    assert(~logical(val),...
                        'Cannot enable second motor when motorDimensionConfiguration is ''%s''.',mdc);
                case 'xy-z'
                    assert(logical(val),...
                        'Second motor must be enabled when motorDimensionConfiguration is ''%s''.',mdc);
                case 'xyz-z'
                    %none
            end

            obj.motorSecondMotorZEnable = val;
        end
        
        function set.motorPosition(obj,val)
            if ~obj.motorHasMotor
                obj.zprvMotorThrowNoMotorWarning();
                return;
            end
            
            if(~obj.overrideFocusIdleAssertion)
                obj.zprvAssertFocusOrIdle('motorPosition');
            end
            val = obj.validatePropArg('motorPosition',val);
            val = val(:)';
            
            if obj.motorHasSecondMotor
                switch obj.motorDimensionConfiguration
                    case 'xy-z'
                        assert(numel(val)==3);
                        
                        currentPos = obj.hMotor.positionRelative(:)';
                        if ~isequal(val(1:2),currentPos(1:2))
                            obj.hMotor.moveCompleteRelative([val(1:2) nan]);
                        end
                        
                        if ~isequal(val(3),obj.hMotorZ.positionRelative(3))
                            obj.hMotorZ.moveCompleteRelative([ nan nan val(3)]);
                        end
                    case 'xyz-z'
                        assert(numel(val)==4);
                        
                        if ~isequal(val(1:3),obj.hMotor.positionRelative(:)')
                            obj.hMotor.moveCompleteRelative(val(1:3));
                        end
                        if ~isequal(val(4),obj.hMotorZ.positionRelative(3))
                            obj.hMotorZ.moveCompleteRelative([ nan nan val(4)]);
                        end
                    otherwise
                        assert(false);
                end
                %TODO (??): Maybe implement FastZPosnGotoAO() operation
                %here..i.e. go to position using either digital
                %(moveComplete) or analog (FastZPosnGotoAO) operation
            else
                assert(numel(val)==3,'Motor position should have three elements.')
                if ~isequal(val,obj.hMotor.positionRelative) % clause is redundant
                    obj.hMotor.moveCompleteRelative(val);
                end
            end
        end
        
        function set.motorUserDefinedPositions(obj,val)
            obj.zprvAssertFocusOrIdle('motorUserDefinedPositions');
            val = obj.validatePropArg('motorUserDefinedPositions',val);
            cellfun(@(v)validateattributes(v,{'numeric'},{'size' [1 obj.motorPositionLength]}), val);  %TODO: Use prop-replacement to directly specify this as part of the property metadata
            obj.motorUserDefinedPositions = val;
        end
        
        function val = get.stackZMotor(obj)
            if ~obj.motorHasMotor
                val = [];
                return;
            end
            
            if obj.motorSecondMotorZEnable
                assert(obj.motorHasSecondMotor);
                val = obj.hMotorZ;
            else
                val = obj.hMotor;
            end
        end
        
        function val = get.stackCurrentMotorZPos(obj)
            val = obj.stackZMotor.positionRelative(3);
        end
        
        function set.stackCurrentMotorZPos(obj,val)
            obj.stackZMotor.moveCompleteRelative([nan nan val]);
        end

        function set.acqState(obj,val)
           obj.acqState = val; 
        end
    end
    
    %% HIDDEN INITIALIZATION METHODS
    methods (Hidden)
        %******************************************************************
        %MOTORS (X/Y/Z STAGE)
        %******************************************************************
        function ziniPrepareMotor(obj)
            obj.hMotor = [];
            obj.hMotorZ = [];
            
            if isempty(obj.mdfData.motorControllerType)
                if ~isempty(obj.mdfData.motor2ControllerType)
                    error('SI5:motorInitErr',...
                        'A secondary z-dimension motor controller was specified without specifying a primary motor controller. This is not supported.');
                end
                fprintf(1,'No motor controller specified in Machine Data File. Feature disabled.\n');
                return;
            end
            
            try
                [obj.hMotor mtrDims1] = obj.ziniMotorConfigureAndConstruct('motor',false);
            catch ME
                fprintf(2,'Error constructing/initializing primary motor:\n%s\n',ME.message);
                fprintf(2,'Disabling motor feature.\n');
            end
            
            if ~obj.motorHasMotor
                return;
            end
            
            if ~isempty(obj.mdfData.motor2ControllerType)
                try
                    [obj.hMotorZ mtrDims2] = obj.ziniMotorConfigureAndConstruct('motor2',true);
                catch ME
                    fprintf(2,'Error constructing/initializing secondary motor:\n%s\n',ME.message);
                    fprintf(2,'Disabling secondary motor.\n');
                end
            end
            
            if isempty(obj.hMotorZ)
                obj.motorDimensionConfiguration = mtrDims1;
            else
                obj.motorDimensionConfiguration = sprintf('%s-%s',mtrDims1,mtrDims2);
            end
            
            switch obj.motorDimensionConfiguration
                case {'xyz' 'xy' 'z' 'xyz-z'}
                    obj.motorSecondMotorZEnable = false;
                case {'xy-z'}
                    obj.motorSecondMotorZEnable = true;
            end
            
            % The following callbacks have to be added to the SI5 object,
            % otherwise acquisition cannot be cancelled in case of a motor
            % failure.
             if obj.motorHasMotor
%                 obj.hMotor.addlistener('LSCError',@(src,evt)obj.zprvMotorErrorCbk(src,evt));
                 obj.hMotor.addlistener('LSCError',@obj.hErrorCallBack);
             end
             if obj.motorHasSecondMotor
%                 obj.hMotorZ.addlistener('LSCError',@(src,evt)obj.zprvMotorErrorCbk(src,evt));
                 obj.hMotorZ.addlistener('LSCError',@obj.hErrorCallBack);
             end
        end
        
        function [motorObj mtrDims] = ziniMotorConfigureAndConstruct(obj,mdfPrefix,tfIsSecondaryMotor)
            
            % Get controller type and info
            type = lower(obj.mdfData.(sprintf('%s%s',mdfPrefix,'ControllerType')));
            regInfo = scanimage.MotorRegistry.getControllerInfo(type);
            
            % Make sure motor is found in motor registry
            assert(~isempty(regInfo), ['Specified motor type (' type ') was not found in the motor registry.']);
    
            % If selected stage is bscope2, see if the bscope2 adapter is already
            % loaded. If so, use it as the LSC. Otherwise instantiate the BScope2
            % device driver as the LSC
            if strcmp('thorlabs.bscope2', type)
                if ~isempty(obj.hModel.hBScope2)
                    if obj.hModel.hBScope2.lscInitSuccessful
                        lscObj = obj.hModel.hBScope2;
                        mtrDims = 'xyz';
                    else
                        motorObj = [];
                        mtrDims = [];
                        return;
                    end
                else
                    hObj = dabs.thorlabs.BScope2('suppressInitWarning', true, 'lsccomport', obj.mdfData.motorCOMPort);
                    if hObj.lscInitSuccessful
                        lscObj = hObj;
                        mtrDims = 'xyz';
                    else
                        motorObj = [];
                        mtrDims = [];
                        return;
                    end
                end
            else
                % Construct/init LSC
                [lscObj mtrDims] = obj.ziniMotorLSCConstruct(regInfo,mdfPrefix,tfIsSecondaryMotor);
            end
            
            % Construct StageController
            motorObj = obj.ziniMotorStageControllerConstruct(regInfo.TwoStep,lscObj,mdfPrefix);
        end
        
        function [lsc mtrDims] = ziniMotorLSCConstruct(obj,info,mdfPrefix,tfIsSecondaryMotor)
            
            % Compile arguments for LSC construction
            lscArgs = struct();
            
            if ~isempty(info.SubType)
                lscArgs.controllerType = info.SubType;
            end
            
            stageType = obj.mdfData.(sprintf('%s%s',mdfPrefix,'StageType'));
            lscArgs.stageType = stageType;
            
            optionalArgMap = containers.Map({'PositionDeviceUnits' 'COMPort' 'BaudRate'},...
                {'positionDeviceUnits' 'comPort' 'baudRate'});
            for key = optionalArgMap.keys
                mdfOptionalData = obj.mdfData.(sprintf('%s%s',mdfPrefix,key{1}));
                if ~isempty(mdfOptionalData)
                    lscArgs.(optionalArgMap(key{1})) = mdfOptionalData;
                end
            end
            
            if ~info.NumDimensionsPreset
                if tfIsSecondaryMotor
                    lscArgs.numDeviceDimensions = 1;
                else
                    lscArgs.numDeviceDimensions = length(obj.motorDimensions);
                end
            end            
            
            if tfIsSecondaryMotor
                mtrDims = 'z';
            else
                mtrDims = lower(obj.mdfData.(sprintf('%s%s',mdfPrefix,'Dimensions')));
                assert(ischar(mtrDims),'Motor dimensions must be a string.');
                if isempty(mtrDims)
                    mtrDims = 'xyz';
                end
            end
            
            % Construct/init LSC
            lscArgsCell = most.util.structPV2cellPV(lscArgs);
            tfErr = false;
            try
                lsc = feval(info.Class,lscArgsCell{:});
                scanimage.StageController.initLSC(lsc,mtrDims);
            catch ME
                tfErr = true;
            end
            
            % For common failures (comPort) provide some guidance
            if tfErr
                if ~isfield(lscArgs,'comPort') || isempty(lscArgs.comPort) || ~isnumeric(lscArgs.comPort)
                    ME.rethrow();
                end
                
                portSpec = sprintf('COM%d',lscArgs.comPort);
                
                % check if our ME matches the case of an open port
                if regexp(ME.message,[portSpec ' is not available'])
                    choice = questdlg(['Motor initialization failed because of an existing serial object for ' portSpec ...
                        '; would you like to delete this object and retry initialization?'], ...
                        'Motor initialization error: port Open','Yes','No','Yes');
                    switch choice
                        case 'Yes'
                            % determine which object to delete
                            hToDelete = instrfind('Port',portSpec,'Status','open');
                            delete(hToDelete);
                            disp('Deleted serial object. Retrying motor initialization...');
                            lsc = feval(info.Class,lscArgsCell{:});
                        case 'No'
                            ME.rethrow();
                    end
                else
                    ME.rethrow();
                end
            end
        end
        
        function scObj = ziniMotorStageControllerConstruct(obj,twoStepInfo,lscObj,mdfPrefix)
            
            scArgs.twoStepEnable = twoStepInfo.Enable;
            if scArgs.twoStepEnable
                
                if isfield(twoStepInfo, 'distanceThreshold')
                    scArgs.twoStepDistanceThreshold = twoStepInfo.distanceThreshold;
                else
                    scArgs.twoStepDistanceThreshold = obj.motorFastMotionThreshold;
                end
                
                % MDF velocity trumps registry velocity. Note that the
                % following may add the field 'velocity' to the
                % FastLSCPropVals, SlowLSCPropVals if it was not there
                % already.
                
                velFast = obj.mdfData.(sprintf('%s%s',mdfPrefix,'VelocityFast'));
                velSlow = obj.mdfData.(sprintf('%s%s',mdfPrefix,'VelocitySlow'));
                if ~isempty(velFast)
                    twoStepInfo.FastLSCPropVals.velocity = velFast;
                end
                if ~isempty(velSlow)
                    twoStepInfo.SlowLSCPropVals.velocity = velSlow;
                end
                
                scArgs.twoStepFastPropVals = twoStepInfo.FastLSCPropVals;
                scArgs.twoStepSlowPropVals = twoStepInfo.SlowLSCPropVals;
                
                %Initialize LSC two-step props to 'slow' values, if specified
                if twoStepInfo.InitSlowLSCProps
                    s = scArgs.twoStepSlowPropVals;
                    props = fieldnames(s);
                    for c=1:numel(props)
                        lscObj.(props{c}) = s.(props{c});
                    end
                end
                
            end
            
            scArgsCell = most.util.structPV2cellPV(scArgs);
            scObj = scanimage.StageController(lscObj,scArgsCell{:});
            scObj.moveCompleteDelay = obj.mdfData.moveCompleteDelay;
        end
    end
    
    %% HIDDEN METHODS (Motor)
    methods (Hidden)
        
        function motorZeroSoft(obj,coordFlags)
            % Do a soft zero along the specified coordinates, and update
            % stackZStart/EndPos appropriately.
            %
            % SYNTAX
            % coordFlags: a 3- or 4-element logical vec. The number of
            % elements should match motorPositionLength.
            %
            % NOTE: it is a bit dangerous to expose the motor publicly, since
            % zeroing it directly will bypass updating stackZStart/EndPos.
            
            if ~obj.motorHasMotor
                obj.zprvMotorThrowNoMotorErr();
            end
            
            coordFlags = logical(coordFlags);
            assert(numel(coordFlags)==obj.motorPositionLength,...
                'Number of elements in coordFlags must match motorPositionLength.');
            
            if strcmp(obj.motorDimensionConfiguration,'xyz-z') && obj.motorSecondMotorZEnable
                tfRescaleStackZStartEndPos = coordFlags(4);
            else
                tfRescaleStackZStartEndPos = coordFlags(3);
            end
            if tfRescaleStackZStartEndPos
                origZCoord = obj.stackZMotor.positionRelative(3);
            end
            
            switch obj.motorDimensionConfiguration
                case {'xyz' 'xy' 'z'}
                    obj.hMotor.zeroSoft(coordFlags);
                case 'xy-z'
                    obj.hMotor.zeroSoft([coordFlags(1:2) false]);
                    obj.hMotorZ.zeroSoft([false false coordFlags(3)]);
                case 'xyz-z'
                    obj.hMotor.zeroSoft(coordFlags(1:3));
                    if numel(coordFlags)==4
                        obj.hMotorZ.zeroSoft([false false coordFlags(4)]);
                    end
            end
            
            if tfRescaleStackZStartEndPos
                obj.hModel.stackZStartPos = obj.hModel.stackZStartPos-origZCoord;
                obj.hModel.stackZEndPos = obj.hModel.stackZEndPos-origZCoord;
            end
        end
        
        function zprvMotorPropSet(obj,prop,val)
            if obj.motorHasMotor
                obj.hMotor.(prop) = val;
            else
                obj.zprvMotorThrowNoMotorWarning();
            end
        end
        
        function zprvMotorZPropSet(obj,prop,val)
            if obj.motorHasSecondMotor
                obj.hMotorZ.(prop) = val;
            else
                obj.zprvMotorThrowNoMotorZWarning();
            end
        end
        
        function zprvMotorThrowNoMotorErr(obj)
            error('SI5:noMotor','Motor operation attempted, but no motor is configured.');
        end
        
        function zprvMotorThrowNoMotorWarning(obj)
            warnst = warning('off','backtrace');
            warning('SI5:noMotor','Motor operation attempted, but no motor is configured.');
            warning(warnst);
        end
        
        function zprvMotorThrowNoMotorZWarning(obj) %#ok<MANU>
            warnst = warning('off','backtrace');
            warning('SI5:noMotorZ','There is no secondary motor.');
            warning(warnst);
        end
        
%         function zprvMotorErrorCbk(obj,src,evt) %#ok<INUSD>
%             if obj.isLive()
%                 fprintf(2,'Motor error occurred. Aborting acquisition.\n');
%                 obj.abort();
%             end
%         end
%         
%         function tf = isLive(obj)
%             tf = ismember(obj.acqState,{'focus' 'grab' 'loop'});
%         end
    end
    
    %% HIDDEN METHODS (Misc)
    methods (Hidden)
        function val = validatePropArg(obj,propname,val)
            val = val;
        end
        
        function zprvResetHome(obj)
            %Reset home motor
            obj.acqMotorPositionStackStart = [];
        end
        
        function zprvSetHome(obj)
            %cache home motor position
            obj.acqMotorPositionStackStart = obj.motorPosition;
        end
        
        function zprvGoHome(obj)
            %Go to home motor/fastZ, as applicable
            if ~isempty(obj.acqMotorPositionStackStart)
                obj.zprvSetInternal('motorPosition', obj.acqMotorPositionStackStart);
            end
        end
    end
end




%--------------------------------------------------------------------------%
% Motors.m                                                                 %
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
