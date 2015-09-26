classdef SI5 < most.Model & most.MachineDataFile
    %SI5 most.Model class for the ScanImage application
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ScanImage';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    
    %% PUBLIC API *********************************************************
    properties (SetObservable)
        
        %acqNumFrames                   - Numeric value. Number of acquired frames, default = 1
        acqNumFrames = 1;
        
        %pixelsPerLine                  - Numeric value. Number of pixels per line, default = 512
        pixelsPerLine = 512;
        
        %linesPerFrame                  - Numeric value. Number of lines per frame, default = 512
        linesPerFrame = 512;
        
        %focusDuration                  - Numeric value. Time, in seconds, to acquire for FOCUS acquisitions, Value of inf implies to focus indefinitely, default = Inf
        focusDuration = Inf; 
        
        %fillFraction                   - Numeric value. Portion of res scanner angular amplitude used for imaging, default = 0.9
        fillFraction = 0.9;
        
        %bidirectionalAcq               - Logical. Bidirectional acquistitin mode, default = true 
        bidirectionalAcq = true;
        
        %flybackLinesPerFrame           - Numeric value. Number of res scanner lines to use for galvo scan flyback, default = 16
        flybackLinesPerFrame  = 16; 
        
        %numFrames                      - Numeric value. Number of frames for acquisition, default = 1
        numFrames = 1;
        
        %acqBeamOverScan                - Numeric array. 1x2 array of times, in microseconds, to 'pad' the fill fraction for ON modulation
        acqBeamOverScan; 
        
        %acqsPerLoop                    - Numeric value. Number of grabs to perform when in acquisition mode 'loop', default = 100
        acqsPerLoop = 100;
        
        %loopAcqInterval                - Numeric value. Time in seconds between two loop repeats in software trigger mode, default = 10
        loopAcqInterval = 10; 
        
        %acqNumAveragedFrames           - Numeric value. Number of frames averaged before storage, default = 1
        acqNumAveragedFrames = 1; 
        
        %channelsActive = 1; %Array specifying which channels (numbered 1 to MAX_NUM_CHANNELS) are active for display and logging
        
        %zoomFactor                     - Numeric array specifying which channels (numbered 1 to MAX_NUM_CHANNELS) are active for display and logging, default = 1
        zoomFactor = 1;
        
        %scanAngleMultiplierSlow        - Numeric value. Slow scan angle multiplier, default = 1
        scanAngleMultiplierSlow=1;
        
        %scanShiftSlow                  - Numeric value. Slow shift, default = 0;
        scanShiftSlow=0;                
        
        %singleChannelNumber = 1;
        
        %chan1LUT                       - Numeric array. Lookup table for channel 1, default = [0 100]
        chan1LUT = [0 100];
        
        %chan2LUT                       - Numeric array. Lookup table for channel 2, default = [0 100]
        chan2LUT = [0 100];
        
        %chan3LUT                       - Numeric array. Lookup table for channel 3, default = [0 100]
        chan3LUT = [0 100];
        
        %chan4LUT                       - Numeric array. Lookup table for channel 4, default = [0 100]
        chan4LUT = [0 100];
        
        %channelsDisplay                - Numeric array of channel indices to be displayed, defaut = 1
        channelsDisplay=1; % TODO public setting of this prop is currently not supported
        
        %channelsSave                   - Numeric array of channel indices to be saved, default = 1
        channelsSave=1; 
        
        %channelsInputRange             - Cell array of 2-element arrays, default = {[-1 1]}
        channelsInputRange={[-1 1]}; 
        
        %channelsSubtractOffset         - Logical array of N elements, indicating whether offset value should be subtracted from acquired data that is saved and/or displayed, for each of the N channels, 
        channelsSubtractOffset = true; 
        
        %channelsAutoReadOffsets        - Logical. If true, channel offsets are automatically read, updating channelOffsets property, prior to each acquisition, default = = true
        channelsAutoReadOffsets = true; 
        
        %channelsReadOffsetsOnStartup = false; %Logical. If true, channel offsets are read on ScanImage startup. Useful for typical cases where channel offsets do not drift/vary during an experimental session.
        
        %%% Logging properties from SI5.m
        
        %loggingFramesPerFile           - Numeric value. Number of frames to store per file, default = inf
        loggingFramesPerFile=inf; 
        
        %%% Fast Z
        
        %fastZEnable                    - Logical. If true, fast Z is enabled, default = false
        fastZEnable = false;
        
        %fastZActive                    - Logical. If true, fast Z is active, default = false
        fastZActive = false;
        
        %fastZNumVolumes                - Numeric value. Number of volumes in fast Z, default = 1
        fastZNumVolumes = 1;
        
        %fastZSettlingTime              - Numeric value. Time of settling for fast Z, default = 0
        fastZSettlingTime = 0;        
        
        %%% Stack properties
        
        %stackNumSlices                 - Numeric value. Number of slices, for either traditional stack collection or fastZ volume collection, default = 1
        stackNumSlices=1;
        
        %stackZStepSize                 - Numeric value. Distance in microns, default = 1
        stackZStepSize=1;
        
        %stackUseStartPower             - Logical. If true, stack uses start power, default = false
        stackUseStartPower=false;
        
        %stackUserOverrideLz            - Logical. If true, override beam Lz values using stackZStart/EndPos, stackStart/EndPower, default = false
        stackUserOverrideLz=false; 
        
        %stackReturnHome                - Logical. If true, motor returns to original z-position after stack, default = true
        stackReturnHome=true; 
        
        %stackStartCentered             - Logical. If true, the current z-position is considered the stack center rather than the stack beginning. Applies to Main::Grab only, default = false
        stackStartCentered=false; 
        
        %%% Shutter properties
        
        %shutterHoldOpenOnStack         - Logical. If true, hold shutter open between slices of a slow stack, default = false.
        shutterHoldOpenOnStack=false; 
                
        %%% Motor properties
        
        %motorSecondMotorZEnable        - Logical. If true, second motor Z is enabled
        motorSecondMotorZEnable;        
        
        %triggerTypeExternal            - Logical. External type flag, default = false;
        triggerTypeExternal = false;
        
        %triggerExternalTerminals       - Cell array. External terminals for trigger matrix, default = {'','',''};
        triggerExternalTerminals = {'','',''};
        
        %triggerExternalEdges           - Cell array. External edges for trigger matrix, default = {'rising','rising','rising'}
        triggerExternalEdges = {'rising','rising','rising'};
     
        %%% User functions properties
        
        %userFunctionsCfg               - Struct array. Nx1 struct array of CFG user function info structs, default= struct('EventName',cell(0,1),'UserFcnName',cell(0,1),'Arguments',cell(0,1),'Enable',cell(0,1))
        userFunctionsCfg = struct('EventName',cell(0,1),'UserFcnName',cell(0,1),'Arguments',cell(0,1),'Enable',cell(0,1)); % Nx1 struct array of CFG user function info structs.
        
        %userFunctionsUsr               - Struct array. Mx1 struct array of USR user function info structs, default = struct('EventName',cell(0,1),'UserFcnName',cell(0,1),'Arguments',cell(0,1),'Enable',cell(0,1))
        userFunctionsUsr = struct('EventName',cell(0,1),'UserFcnName',cell(0,1),'Arguments',cell(0,1),'Enable',cell(0,1)); % Mx1 struct array of USR user function info structs.
        
        %userFunctionsOverride          - Struct array. Px1 struct array of user override functions, default = struct('Function',cell(0,1),'UserFcnName',cell(0,1),'Enable',cell(0,1))
        userFunctionsOverride = struct('Function',cell(0,1),'UserFcnName',cell(0,1),'Enable',cell(0,1)); % Px1 struct array of user override functions
        
        %%% Bscope2 variables
        
        %bscope2PmtValsSet              - Logical. Bscope2 values-set, default = false
        bscope2PmtValsSet = false;
        
        %bscope2PmtPowersOn             - Logical array. Bscope2 powers-on array, default = logical([0 0 0 0])
        bscope2PmtPowersOn = logical([0 0 0 0]);
        
        %bscope2PmtGains                - Numeric array. Bscope2 gains array, default = [0 0 0 0]
        bscope2PmtGains = [0 0 0 0];
        
        %bscope2PmtTripped              - Numeric array. Bscope2 tripped array, default = [0 0 0 0]
        bscope2PmtTripped = [0 0 0 0];
        
        %bscope2FlipperMirrorPosition   - String. Bscope2 flippler mirror position, default = 'pmt'
        bscope2FlipperMirrorPosition = 'pmt';
        
        %bscope2GalvoResonantMirrorInPath - Numeric value. Bscope2 galvo resonant mirror in path, default = 1
        bscope2GalvoResonantMirrorInPath = 1;
        
        %bscope2GalvoGalvoMirrorInPath  - Numeric value. Bscope2 galvo-galvo mirror in path, default = 0
        bscope2GalvoGalvoMirrorInPath = 0;
        
        %bscope2ScanAlign               - Numeric value. Bscope2 scan alignment, default = 0;
        bscope2ScanAlign = 0;
    end
    
    properties (Hidden, SetObservable, SetAccess=private)
        
        %bscope2RotationAngle           - Numeric value. Bscope2 rotation angle
        bScope2RotationAngle;
        
    end
    
    properties (SetObservable, Transient)
        
        %%% Pixel constraints
        
        %scanForceSquarePixelation      - Transient logical. If true, pixelsPerLine and linesPerFrame are constrained to be equal, default = true
        scanForceSquarePixelation=true; 
        
        %canForceSquarePixel            - Transient logical. If true, pixelation ratio is locked equal to scan angle multiplier ratio, to maintain square pixel aspect ratio, default = true
        scanForceSquarePixel=true; 
        
        %%% Acquisition flow
        
        %acqFrameBufferLengthMin        - Transient numeric value. Minimum number of most-recently acquired frames to store in acqFrameBuffer, default = 2
        acqFrameBufferLengthMin = 2; 
        
        %%% Logging
        
        %loggingEnable                  - Transient logical. If true, logging is enabled, default = false
        loggingEnable = false;
        
        %loggingFileCounterAutoReset    - Transient logical. If true, loggingFileCounter reset to 1 on change of loggingFileStem, default = true
        loggingFileCounterAutoReset=true; 
        
        %loggingFramesPerFileLock       - Transient logical. Constrain loggingFramePerFile to equal acqNumFrames -- this is typical/useful for collecting a single file per slice
        loggingFramesPerFileLock=false;
        
        %loggingFilePath                - Transient string. Logging filepath, default = ''
        loggingFilePath = '';
        
        %loggingFileStem                - Transient string. Logging filestem, default = ''
        loggingFileStem = '';
        
        %loggingFileCounter             - Transient numeric value. Logging file counter, default = 1
        loggingFileCounter = 1;
        
        %loggingFileSubCounter          - Transient numeric value. Logging file subcounter, default = 1
        loggingFileSubCounter = 1;
        
        %%% Display
        
        %displayShowCrosshair           - Transient logical. If true, display crosshair overlay on image displays, default = false
        displayShowCrosshair            = false; 
        
        %displayRollingAverageFactorLock - Transient logical. If true, lock acqNumAveragedFrames = displayRollingAverageFactor, default = false
        displayRollingAverageFactorLock = false; 
        
        %displayFrameBatchSelectLast    - Transient logical. If true, lock displayFrameBatchFactor = displayFrameBatchSelection, default = = true
        displayFrameBatchSelectLast     = true; 
        
        %displayFrameBatchFactorLock    - Transient logical. If true, lock displayFrameBatchFactor = displayRollingAverageFactor, default = false
        displayFrameBatchFactorLock     = false;
        
        %displayRollingAverageFactor    - Transient numeric value. Number of frames averaged (using a simple moving average) for display purposes. Value must be greater or equal to acqNumAveragedFrames, default = 1
        displayRollingAverageFactor     = 1; 
        
        %displayFrameBatchFactor        - Transient numeric value. Number of frames to batch together for selective or tiled display, default = 1
        displayFrameBatchFactor         = 1; 
        
        %displayFrameBatchFactorCounter - Transient numeric value. Frames number within a batch which the zzzFrameDisplayFunction will update, default = 1
        displayFrameBatchFactorCounter  = 1; 
        
        %displayFrameBatchSelection     - Transient numeric value. Frame or frames to display within each frame batch, default = 1
        displayFrameBatchSelection      = 1; 
        
        %displayDecimationFactor        - Transient numeric value. Amount of frames to decimate when sending image data to the MATLAB thread. A value of 1 sends 1 event/frame to the MATLAB event queue. A value of 10 sends 1 event/10 frames, default = 1
        displayDecimationFactor         = 1; 
        
        %displayBatchingFactor          - Transient numeric value. Amount of frames to batch when sending image data to the MATLAB thread. A value of 10 sends 10 images per MATLAB event, default = 1
        displayBatchingFactor           = 1; 
        
        %displayLastFrameDisplayed      - Transient numeric value. Internal accounting of last frame displayed for frame display function, default = 0
        displayLastFrameDisplayed       = 0; 
        
        %%% Merge display
        
        %channelsMergeColor             - Transient string cell array of color names, default =  = {'green' 'red' 'gray' 'none'}
        channelsMergeColor = {'green' 'red' 'gray' 'none'}; 
        
        %channelsMergeEnable            - Transient logical. If true, the channels merge window is updated, default = false
        channelsMergeEnable = false; 
        
        %channelsMergeFocusOnly         - Transient logical. If true, the channels merge image is not updated during GRAB/LOOP acquisitions, default = false
        channelsMergeFocusOnly = false; 

        %%% Fast configurations              
        
        %fastCfgCfgFilenames            - Transient cell array. FAST_CFG_NUM_CONFIGSx1 array of Cfg filenames, default = repmat({''},scanimage.SI5.FAST_CFG_NUM_CONFIGS,1)
        fastCfgCfgFilenames  = repmat({''},scanimage.SI5.FAST_CFG_NUM_CONFIGS,1);
        
        %fastCfgAutoStartTf             - Transient logical array. AutoStart flag, default = false(scanimage.SI5.FAST_CFG_NUM_CONFIGS,1)
        fastCfgAutoStartTf   = false(scanimage.SI5.FAST_CFG_NUM_CONFIGS,1);
        
        %fastCfgAutoStartType           - Transient cell array. Autostart type, default= cell(scanimage.SI5.FAST_CFG_NUM_CONFIGS,1)
        fastCfgAutoStartType = cell(scanimage.SI5.FAST_CFG_NUM_CONFIGS,1);
                   
        %%% Debug stuff
        
        %debugFrameNumbers              - Transient logical. If true debug flag is set, default = false
        debugFrameNumbers = false; 
        
        %scanParamCache                 - Transient cache for 'Base' value of ROI scan parameters (scanZoomFactor, scanAngleMultiplier, scanOffset, scanRotation)
        scanParamCache; %TODO: Ultimately may want this Hidden or protected in some way -- fully public for now for usrFile handling
                
    end
    
    
    properties (SetObservable, Dependent)
        %scanPixelTimeMean              - Dependent numeric value. Mean time spent dwelling at each pixel, during each line
        scanPixelTimeMean; 
        
        %scanPixelTimeMaxMinRatio       - Dependent numeric value. Ratio of max-to-min time spent dwelling at each pixel across the line scan
        scanPixelTimeMaxMinRatio; 
    end
    
    properties (SetObservable,Dependent,AbortSet)
        %frameAcqFcnDecimationFactor    - Dependent, AbortSet integer N indicating that only every Nth frame is processed in Matlab in SI5, e.g. reducing display rate, etc., default = 1
        frameAcqFcnDecimationFactor = 1; 
    end    
    
    properties (SetObservable, Dependent, Transient)
        %beamPowerLimits                - Dependent, transient numeric array. Contains power limit for each beam
        beamPowerLimits; 
    end        
    
    %Following properties are Dependent as they delegate to adapters for actual implementation 
    properties (SetObservable, Dependent)
        %fillFractionTime               - Dependent numeric value. Portion of res scanner half-period used for imaging during each line        
        fillFractionTime; 
        
        %%% Beam properties
        
        %beamNumBeams                   - Dependent numeric value. Number of beams in the rig
        beamNumBeams;
        
        %beamPowers                     - Dependent numeric array. Contains power level for each beam
        beamPowers;
        
        %beamPzAdjust                   - Dependent logical scalar. Indicates whether power/z adjustment is enabled globally, according to beamLengthConstants specified for each beam
        beamPzAdjust; 
        
        %beamDirectMode                 - Dependent logical. Indicates that power should be turned on and take effect immediately after all beamPowers adjustments
        beamDirectMode; 
        
        %beamLengthConstants            - Dependent numeric array. Contains length constant for each beam, to use for power adjustment during Z stacks
        beamLengthConstants; 
        
        %beamFlybackBlanking            - Dependent logical. Indicates whether to blank beam outside of fill fraction
        beamFlybackBlanking; 
        
        %%% Fast Z (look in FastZ.m for additional definitions)
        
        %fastZImageType                 - Dependent cell array. One of {'XY-Z' 'XZ' 'XZ-Y'}
        fastZImageType;
        
        %fastZScanType                  - Dependent cell array. One of {'step' 'sawtooth'}
        fastZScanType;
        
        %fastZDiscardFlybackFrames      - Dependent logical. Indicates whether to discard frames during fastZ scanner flyback
        fastZDiscardFlybackFrames;
        
        %fastZFramePeriodAdjustment     - Dependent numeric value. Time, in us, to deduct from the nominal frame period, when determining fastZ sawtooth period used for volume imaging
        fastZFramePeriodAdjustment;
        
        %fastZAllowLiveBeamAdjust       - Dependent logical. Indicates whether to allow live adjustment of beamPowers during fastZ imaging
        fastZAllowLiveBeamAdjust;
        
        %fastZPeriod                    - Dependent numeric value. Time specification in seconds. Co-varies with stackNumSlices/stackZStepSize. For fastZScanType='sawtooth', specifies period of scan in fastZ dimension. For fastZScanType='step', specifieds time or times (if supplied as vector) to spend at each step (i.e. value per element in fastZScanRangeSpec)
        fastZPeriod;
        
        %fastZFillFraction              - Dependent numeric value. Fraction of frames in acquisition stream during fastZ imaging
        fastZFillFraction;
        
        %fastZAcquisitionDelay          - Dependent numeric value. Acquisition delay, in seconds, of fastZScanner. Value is exactly 1/2 the fastZSettlingTime
        fastZAcquisitionDelay;
    end
    
    
    %%% READ ONLY / PRIVATE PROPERTIES
       
    %%% Effectively read-only via DependsOn/mdlDummyPropSet
    properties (SetObservable, Dependent)
        %scanFramePeriod                - Read only, dependent numeric value. Period of scan frame
        scanFramePeriod;
        
        %scanPixelTimeStats             - Read only, dependent structure. Structure of computed pixel dwell time statistics
        scanPixelTimeStats; 
        
        %fastZNumDiscardFrames          - Read only, dependent numeric value. Number of discarded frames per-volume for XY-Z, XZ-Y cases and per-frame for XZ case
        fastZNumDiscardFrames;
    end
        
    properties (SetObservable, SetAccess=protected)
        
        %acqState                       - Read only, protected string. One of {'focus' 'grab' 'loop' 'loop_wait' 'idle' 'point'}, default = 'idle'
        acqState = 'idle'; 
        
        %acqMode                        - Read only, protected string. One of {'focus' 'grab' 'loop'}
        acqMode;
        
        %overvoltageStatus              - Read only, protected logical. If true, over-voltage condition, default = false
        overvoltageStatus = false;
        
        %channelOffsets                 - Read only, protected array. Nx1 array, where N=MAX_NUM_CHANNELS. Contains digitizer/PMT offset value last measured for each channel
        channelOffsets; 
       
        %acqStartTime                   - Read only, protected numeric value. Time at which the current acquisition started. This is not used for any purpose other than "soft" timing
        acqStartTime; 
        
        %acqModeStartTime               - Read only, protected numeric value. Time at which the current mode acquisition started. This is not used for any purpose other than "soft" timing
        acqModeStartTime; 
        
        %usrFilename                    - Read only, protected string. User filename, default = ''
        usrFilename = '';

        %cfgFilename                    - Transient, protected string. Cfg filename, default = ''
        cfgFilename = '';       

        
    end
    
        
    properties (SetObservable,SetAccess=protected, Transient)   
        %usrPropListCurrent             - Transient, protected cell array. List of props that are included in USR file, default = scanimage.SI5.USR_PROP_LIST_DEFAULT
        usrPropListCurrent = scanimage.SI5.USR_PROP_LIST_DEFAULT; %NOTE: For SI5, we will disallow setting of usrPropListCurrent (via SetAccess=protected)

        %%% Acquisition flow

        %secondsCounter                 - Transient, protected numeric value. current countdown or countup time, in seconds, default = 0
        secondsCounter = 0; 
        
        %stackSlicesDone                - Transient, protected numeric value. Number of slices acquired in current GRAB acquisition or LOOP repeat, default = 0
        stackSlicesDone = 0; 
        
        %scanFramesStarted              - Transient, protected numeric value. Count of frame triggers received, based on the NI frame period counter Task, during an uninterrupted acquisition interval (i.e. between zprvStartFocus/zprvStartAcquisitionSlice() and zprvStopAcquisition()), default = 0
        scanFramesStarted = 0; 
        
        %loopAcqCounter                 - Transient numeric value. Number of grabs completed in acquisition mode 'loop', default = 0
        loopAcqCounter = 0;   
        
        %acqFramesDone                  - Read only numeric value. Number of frames already acquired in current slice of current GRAB acquisition or LOOP repeat, default = 0
        acqFramesDone = 0; 
        
        %acqFramesDoneTotal             - Read only numeric value. Tally of total frames acquired since last start trigger (including trigger of last slice if a stack acquisition).  Value is determined by simply counting executions of frameAcquiredFcn() callback. In fastZmode, value may differ from acqFramesDone, default = 0
        acqFramesDoneTotal=0; 
        
        %fpgaFrameNumberAcqMode         - Transient read only numeric value. counter of frames in the current acquisition mode on the fpga
        fpgaFrameNumberAcqMode = 0;
        
        %fpgaFrameNumberAcq             - Transient read only numeric value. counter of frames in the current acquisition on the fpga
        fpgaFrameNumberAcq = 0;
        
        %fpgaLastEndOfAcquisition       - Transient read only numeric value. frame count at last end of acquisition on the fpga
        fpgaLastEndOfAcquisition = 0;
        
        %fpgaAcqCounter                 - Transient read only numeric value. counter of finished acquisitions on the fpga
        fpgaAcqCounter = 0;
    end
    
    
    properties (SetObservable, Dependent, SetAccess=protected, Transient)        
        %acqFrameBufferLength           - Dependent, protected, transient numeric value. Length of running buffer used to store most-recently acquired frames
        acqFrameBufferLength; %Length of running buffer used to store most-recently acquired frames
        
        %secondsCounterMode             - Dependent. protected, transient string. One of {'up' 'down'} indicating whether this is a count-up or count-down timer
        secondsCounterMode; %One of {'up' 'down'} indicating whether this is a count-up or count-down timer
        
        %acqNumFramesPerTrigger         - Dependent, protected, transient numeric value. Number of frames to grab in once cycle in acquisition modes 'grab' or 'loop'
        acqNumFramesPerTrigger; % Number of frames to grab in once cycle in acquisition modes 'grab' or 'loop
    end                    
       


    
    %% HIDDEN API *********************************************************
    
    %Some props are public yet hidden, because of the property doubling
    %currently needed for subsystems. To be fixed.
    properties (Hidden)
        acqFrameBuffer = {}; %Cell array containing most recently acquired acqFrameBufferLength frames
        acqFrameNumberBuffer = {}; %Cell array containing frame numbers of most recently acquired acqFrameBufferLength frames
        
        %TODO: Multiple ROI
        mroiEnabled = false;
        multiChannel = false;
        
        cachedLoggingEnable = false;
        
        scanPhaseRange = [-500 1000];
        scanPhaseMap = containers.Map({1},{0}); %containers.Map() that holds the LUT values for scan phase.
                
        %internal "end of acquisition" signal
        endOfAcquisitionFlag=false;
        
        frameCounterLastAcq = 0;% Number of frames acquired at last acq. Used to zero the frame display counter between Acqs.
        frameCounter = 0;       % Number of frames acquired
        
        fastZNumFramesPerVolume; %Number of frames per volume for current acq & fastZ settings
        
        %flag props set flags
        scanSetPixelationPropFlag;
        internalSetFlag = false; %What is this used for?? 
        
    end
    
    
    properties(Dependent, Hidden)
        
        
        channelsInputRangeValues; %Nx2 array, with each row representing an allowable range value (2-element arrays, specifying min-max)
        channelsBitDepth;
        channelsLUTRange;         %2 element array specifying min-max values allowed for channelsLUT
        channelsDataType;
        
        stackStartEndPointsDefined; % logical; if true, stackZStartPos, stackZEndPos are defined (non-nan)
        
        fastZUseAOControl;
        
    end
    
    properties (Hidden)
        %scanPhaseModes: 'Nearest Neighbor','Interpolate','Next Lower,'Next Higher'
        %
        % Note: This is all just guessing. The user must either explicitly set scan phases for all zoom levels or we have to make a way for
        % the scanner to automatically set the scan phase for perfect bidi alignment.
        %
        % Interpolate:      Linearly interpolate between next lower and next higher zoom factor with a set scan phase.
        % Nearest Neighbor: Choose between scan phase of next lower and next higher zoom factor with a set scan phase, whichever zoom factor is closest to current.
        % Next Lower:       Choose the scan phase of the next lower zoom factor  with a set scan phase.
        % Next Higher:      Choose the scan phase of the next higher zoom factor with a set scan phase.
        %
        scanPhaseMode='Next Lower';
        stackShutterCloseMinZStepSize = 0; %Minimum stackZStepSize, in um, above which shutter will be closed, i.e. to allow for move to complete. For smaller moves, shutter will remain open during stack motor step - i.e. rely on Pockels blanking to limit illumination.
        scanPhaseChanged = false; % Internal flag used to check if scan phase was changed by user (as opposed to being changed by the zoom control.)
        zoomChanged = false;      % Internal flag used to check if the zoom was changed by the user.
    end
    
    %%% READ-ONLY / PRIVATE
    
    properties (Hidden,SetAccess=protected)
        hBeams;         % Beam Object handle.
        hShutters;      % Shutter Object handle.
        hMotors;        % Motor Object handle.
        hFastZ;         % FastZ Object handle.
        hAcq;           % Handle to FPGA-based acquisition module
        hScan;          % Handle to scanner control unit (res scanner & galvo control)
        hTriggerMatrix; % Handle to Trigger Matrix
        %hPlugins;       % Handle to Plugins
        hPMTs;          % Handle to PMT controller object
        hECU1;          % Handle to ThorECU1 object
        hBScope2;       % Handle to ThorBScope2 object
        
        mask = [];
        
        hFigs = [-1 -1 -1 -1];
        hAxes = { -1 -1 -1 -1 };
        hImages = { -1 -1 -1 -1 };
        hText = { -1 -1 -1 -1 };
        
        hMergeFigs = [-1 -1 -1 -1];
        hMergeAxes = [-1 -1 -1 -1];
        hMergeImages = [-1 -1 -1 -1];
        
        hLoopRepeatTimer;
        hDisplayRefreshTimer;
        
        displayInternalTileIdx = 1; %Internal accounting of tile index for timer display function.
        displayRollingBuffer; %Array used for display averaging computation. Stored as double type.
        motorDimensionConfiguration; % one of {'none' 'xy' 'z' 'xyz'} when there is a single motor; one of {'xy-z' 'xyz-z'} when there are two motors
        stackSlowArmed=false; %True if slow stack armed, false if not (used by timerfcn).
        stackRefZPos; % Cache of refernce z position to base all z moves on. Not the same as the home position for a centered stack!
        stackLastStartEndPositionSet = nan; % Cache of last position set to stackZStartPos/stackZEndPos. Used to throw warning re: running stack with possibly stale start/end pos.
        
        userFunctionsCfgListeners; % Column cell array containing listener objects for user functions (CFG). There is a 1-1 correspondence between these objects and the elements of userFunctionsCfg.
        userFunctionsUsrListeners; % Column cell array containing listener objects for user functiosn (USR). There is a 1-1 correspondence between these objects and the elements of userFunctionsUsr.
        userFunctionsOverriddenFcns2UserFcns; % Scalar struct. Fields: currently overridden fcns. vals: user fcns to call instead.
        
        triggerExternalTerminalOptions; % string array of configurable trigger terminals
        
        cfgLoading = false;
    end
    
    properties (Dependent,Hidden,SetAccess=protected)
        usrCfgFileVarName; % varName stored in a USR file for cfg file associated with that USR file
        displayShowCrosshairTrue; %Logical indicating if crosshair display is actually active
    end
    
    %Following are informational props created specificalliy for benefit of possible GUI bindings in Controllers
    %So they are SetObservable despite being Hidden
    
    properties (SetObservable, Hidden)
        beamPowersDisplay; % The displayed beam power        
    end
    
    properties (SetObservable, Hidden, SetAccess = private)
        frameCounterDisplay = 0;% Number of frames acquired - this number is displayed to the user.
        triggerExternalTypes;
        digitalIODeviceIsFPGA = false;
    end        
    
    %Hidden only because they are not currently implemented
    properties (SetObservable, Hidden)
        beamPowerUnits; %One of {'percent', 'milliwatts'}
        beamLiveAdjust=true; %Logical indicating whether beamPowers can be adjusted during scanning. Doing so will disable flyback blanking, if enabled.
    end
    
    % Following Hidden props either:
    %   have DependsOn attribute --> typically SetObservable
    %   are identified as a DependsOn value (for another property) --> must be SetObservable
    
    properties (SetObservable, Dependent, Hidden)
        linePeriod_;
        scanFrameRate_;
        
        scanForceSquarePixel_; %Logical indication if scanForceSquarePixel constraint is in effect
        scanForceSquarePixelation_; %Logical indication if scanForceSquarePixelation constraint is in effect
        
        triggerExternalAvailable;
    end
    
    
    
    
    % Following Hidden props should be public, but are Hidden because they mirror a submodel prop value
    % This property doubling/mirroring will be eliminated in future SI5 version with full submodel support in Most
    % They are SetObservable as the Controller class in this SI5 version requires binding to a root model, not a submodel, prop
    properties (SetObservable, Hidden)
        fastZVolumesDone;
        
        motorPosition; % 1x3 or 1x4 array specifying motor position (in microns), depending on single vs dual motor, and motorDimensionConfiguration.
        
        periodClockPhase = 0;   % in FPGA ticks
        
        resonantScannerFreq = 7910;
        
        stackZStartPos=nan; %z-position from Motor::stack panel; does NOT apply to all acqs. This position is _relative to hMotor's relative origin_. It is _not_ in absolute coords.
        stackZEndPos=nan; %z-position from Motor::stack panel; does NOT apply to all acqs. This position is _relative to hMotor's relative origin_. It is _not_ in absolute coords.
        
        stackStartPower=nan; % beam-indexed
        stackEndPower=nan; % beam-indexed
        
    end
    
    
    
    %% CONSTANTS **********************************************************
    properties(Constant)
        %Properties capturing the ScanImage version number - a single number plus the service pack number
        %Snapshots between service pack releases should add/subtract 0.5 from prior service pack to signify their in-betweenness
        VERSION_MAJOR = 5; %Version number
        VERSION_MINOR = 0; %Service pack number (0 = the official release; positive numbers = service packs post release; negative numbers = early access release numbers, -1 is first, -2 second, etc)
    end
    
    properties(Constant, Hidden)
        % Static Trigger Input/Output assignment
        STATIC_TRIGGER_MAP_FPGA = {'beamModifiedLineClockOut','/FPGA/DIO1.0';'frameClockOut','/FPGA/DIO1.1';'acqTriggerOut','/FPGA/DIO1.2'};
        STATIC_TRIGGER_MAP_DAQ  = {'beamModifiedLineClockOut','PFI5';'frameClockOut','PFI6';'acqTriggerOut','PFI7'};
        STATIC_TRIGGER_TERMINALS_FPGA = {'/FPGA/DIO0.0' '/FPGA/DIO0.1' '/FPGA/DIO0.2' '/FPGA/DIO0.3'};
        STATIC_TRIGGER_TERMINALS_DAQ  = {'PFI1' 'PFI2' 'PFI3' 'PFI4'};
        
        SCAN_PARAM_CACHE_PROPS = {'scanAngleMultiplierSlow' 'scanShiftSlow'};
        MAX_NUM_CHANNELS = 4;
        LOOP_TIMER_PERIOD = 1;
        REFRESH_TIMER_PERIOD = 0.030;
        FAST_CFG_NUM_CONFIGS = 6;
        
        % List of props that may/must be included in USR file
        USR_AVAILABLE_USR_PROP_LIST = most.Model.getDefaultConfigProps('scanimage.SI5');
        VERSION_PROP_NAMES =  {'VERSION_MAJOR'; 'VERSION_MINOR'}; %These props included in USR and CFG files, as well as file header data
        
        % List of props that are included in USR file by default
        USR_PROP_LIST_DEFAULT = {...
            'focusDuration';
            'acqFrameBufferLengthMin';
            ...
            'fastCfgCfgFilenames';'fastCfgAutoStartTf';'fastCfgAutoStartType';
            'beamPzAdjust';'beamLengthConstants';
            'stackUserOverrideLz';
            'userFunctionsUsr';
            'displayShowCrosshair';
            'channelsMergeColor';'channelsMergeEnable';'channelsMergeFocusOnly';
            'channelsAutoReadOffsets';'channelsSubtractOffset' %;'channelsReadOffsetsOnStartup';
            'scanParamCache';
            'loggingFileCounterAutoReset';
            'acqBeamOverScan';
            'chan1LUT';'chan2LUT';'chan3LUT';'chan4LUT';
            'motorSecondMotorZEnable';'shutterHoldOpenOnStack'
            };
        
        USER_FUNCTIONS_EVENTS = zlclInitUserFunctionsEvents(); % column cellstr of events for user-functions.
        USER_FUNCTIONS_USR_ONLY_EVENTS = zlclInitUserFunctionsUsrOnlyEvents(); % column cellstr of USR-specific events for user-functions
        USER_FUNCTIONS_OVERRIDE_FUNCTIONS = {'frameAcquiredFcn';'triggerFcn'};
    end
    
    % *********************************************************************
    % *********************************************************************
    % *********************************************************************
    
    %% PUBLIC EVENTS (for user functions) *********************************
    % Built-in events
    events (NotifyAccess=protected)
        acqModeStart;          %[x] Fires when a GRAB or LOOP acquisition mode has been started.
        acqModeDone;           %[x] Fires when a GRAB or LOOP acquisition mode has completed.
        acqStart;              %[x] Fires when a new acquisition within an ongoing GRAB/LOOP has been started.
        acqDone;               %[x] Fires when a GRAB acquisition, or single iteration of LOOP acquisition, has completed
        acqAbort;              %[x] Fires when a GRAB or LOOP acquisition has been aborted
        
        sliceDone;             %[x] Fires when single slice of a multi-slice GRAB/LOOP acquisition has completed
        focusStart;            %[x] Fires when a FOCUS acquisition has been started.
        focusDone;             %[x] Fires when FOCUS acquisition is completed
        
        frameAcquired;         %[x] Fires when acquisition of frame has been completed
        overvoltage;           %[x] Fires when the digitizer experiences a overvoltage condition
    end
    
    % Built-in user-only events
    events (NotifyAccess=private) % use private/protected attribute to distinguish usr-only events (arbitrary hack)
        applicationOpen;          % Fires when application is finished starting up
        applicationWillClose;     % Fires when application is about to close
    end
    
    %% HIDDEN EVENTS ******************************************************
    events (Hidden, NotifyAccess=protected)
        motorPositionUpdate; %Signals that motor position has been, or may have been, updated
    end
    
    % *********************************************************************
    % *********************************************************************
    % *********************************************************************
    
    %% LIFECYCLE
    methods
        function obj = SI5()
            obj.notify('applicationOpen');
            
            %Initialize class data file (ensure props exist in file)
            obj.zprvEnsureClassDataFileProps();
            
            %Initialize the scan phase map (from value in Class Data File)
            obj.scanPhaseMap = obj.getClassDataVar('scanPhaseMap');
            if ~isa(obj.scanPhaseMap,'containers.Map')
                fprintf('Warning: scanPhaseMap in Class Data File was empty - usually this occurs when starting with a brand new SI5 install. Replacing with empty map.\n');
                obj.scanPhaseMap = containers.Map({1},{0});
            end
            
            %Open FPGA acquisition adapter
            obj.hAcq = scanimage.adapters.ResonantAcq(obj);
            
            %Register the callback with the scanner controller.
            obj.hAcq.frameAcquiredFcn = @(src,evnt)obj.zzzFrameAcquiredFcn;
            
            %Initialize trigger props & routing in PXI system.
            obj.triggerExternalTypes = {'Acquisition Start','Acquisition Stop','Next File Marker'};
            
            %Determine what kind of digital IO device is specified
            try
                dabs.ni.daqmx.Device(obj.mdfData.digitalIODeviceName);
                %if the previous line did not produce an exception, the daq device was found.
                obj.digitalIODeviceIsFPGA = false;
            catch
                %right now there is no way to test if we have a valid RIO device name
                %therefore is device is not in daqmx, assume it is a RIO
                obj.digitalIODeviceIsFPGA = true;
            end
            
            if obj.digitalIODeviceIsFPGA
                assert(strcmp(obj.mdfData.digitalIODeviceName, obj.hAcq.mdfData.rioDeviceID), 'RIO device for digital IO must be same as RIO device for ResonantAcq.');
                obj.triggerExternalTerminalOptions = obj.STATIC_TRIGGER_TERMINALS_FPGA;
                obj.hTriggerMatrix = scanimage.adapters.TriggerMatrix(obj,obj.mdfData.primaryPxiChassisNum,[],obj.mdfData.simulated);
            else
                obj.triggerExternalTerminalOptions = obj.STATIC_TRIGGER_TERMINALS_DAQ;
                obj.hTriggerMatrix = scanimage.adapters.TriggerMatrix(obj,obj.mdfData.primaryPxiChassisNum,obj.mdfData.digitalIODeviceName,obj.mdfData.simulated);
            end
            
            obj.triggerExternalTerminalOptions = [{''} obj.triggerExternalTerminalOptions];
            
            %Open scanner control adapter
            obj.hScan = scanimage.adapters.ResScanCtrl(obj,obj.mdfData.simulated);
            
            % Res Scan Ctrl hard resets the main daq device, so that all
            % routes are cleared. setting up the trigger routing needs to
            % occur after the hard reset
            obj.updateStaticTriggerRouting();
            
            %Initialize optional Shutter hardware
            obj.hShutters = scanimage.adapters.Shutters(obj,obj.mdfData.digitalIODeviceName,obj.digitalIODeviceIsFPGA);
            
            %Initialize optional hardware for 'beam' modulation (e.g. Pockels), including calibration (e.g. with photodiode)
            obj.hBeams = scanimage.adapters.Beams(obj);
            obj.hBeams.scanLinePeriod = obj.hAcq.scanLineDuration;
            if (obj.bidirectionalAcq)
                obj.hBeams.scanMode = 'bidirectional';
            else
                obj.hBeams.scanMode = 'unidirectional';
            end
            obj.hBeams.scanFillFraction = obj.fillFraction;
            
            %Initialize ThorECU1 object
            obj.hECU1 = [];
            if strcmp(obj.mdfData.scannerHardwareType, 'ecu1')
                %warning('ThorECU1 interface support is not yet implemented.');
                obj.hECU1 = scanimage.adapters.ThorECU1(obj);
            end
            
            %Initialize ThorBScope2 object
            obj.hBScope2 = [];
            if strcmp(obj.mdfData.scannerHardwareType, 'bscope2')
                obj.hBScope2 = scanimage.adapters.ThorBScope2(obj);
            end
            
            %Initialize optional motor hardware for X/Y/Z motion
            obj.hMotors = scanimage.adapters.Motors(obj);
            %Set up callback for motor errors:
            obj.hMotors.hErrorCallBack = @(src,evt)obj.zprvMotorErrorCbk(src,evt);
            
            %Initialize optional hardware for fast-Z translation
            obj.hFastZ = scanimage.adapters.FastZ(obj);
            
            %Compute the scan frame period at startup. This should be
            %replaced by a LUT or whatever value is measured by the system.
            obj.hFastZ.scanFrameRate = obj.scanFrameRate_;
            
            %Initialize handle to PMT controllers (if any)
            obj.hPMTs = scanimage.adapters.Pmts(obj);
            
            obj.ziniPrepareDisplayFigs();
            obj.ziniPrepareChannels();
            
            obj.hLoopRepeatTimer = timer('BusyMode','drop',...
                'ExecutionMode','fixedRate',...
                'StartDelay',obj.LOOP_TIMER_PERIOD, ...
                'Period',obj.LOOP_TIMER_PERIOD, ...
                'TimerFcn',@obj.zzzLoopTimerFcn);
            
            obj.hDisplayRefreshTimer = timer('BusyMode','drop',...
                'ExecutionMode','fixedRate',...
                'StartDelay',obj.REFRESH_TIMER_PERIOD, ...
                'Period',obj.REFRESH_TIMER_PERIOD, ...
                'TimerFcn',@obj.zzzFrameDisplayFcn2);
            
            %Reset Buffers for Frame Averaging
            obj.zprvResetBuffers();
            
            %             %Read channel offsets
            %             if isprop(obj,'channelsReadOffsetsOnStartup') && obj.channelsReadOffsetsOnStartup
            %                 btn = questdlg('Read input channel offsets now or later? Input signals should be connected exactly as they will be during imaging - e.g., PMT on with gain set to value used during imaging.','Read Channel Offsets','Now','Later','Now');
            %                 if strcmpi(btn,'now')
            %                     obj.channelsReadOffsets();
            %                 end
            %             end
            
            %Load default values for nominalResScanFreq hAcq and hScan from MDF
            validateattributes(obj.mdfData.nominalResScanFreq,{'numeric'},{'scalar','positive','finite'});
            obj.resonantScannerFreq = obj.mdfData.nominalResScanFreq;
            obj.hAcq.scannerFrequency = obj.resonantScannerFreq;
            obj.hScan.resonantScannerFreq = obj.resonantScannerFreq;
            
            %             %Load plugins
            %             obj.zprvLoadPlugins();
        end
        
        function initialize(obj)
            %Load user file (which adjusts figure positions)
            obj.usrLoadUsr();
            
            %Initialize model, which also calls initialize() on any/all controller(s)
            initialize@most.Model(obj);            
                   
            
            %             %Read channel offsets
            %             if  obj.channelsReadOffsetsOnStartup
            %                 btn = questdlg('Read input channel offsets now or later? Input signals should be connected exactly as they will be during imaging - e.g., PMT on with gain set to value used during imaging.','Read Channel Offsets','Now','Later','Now');
            %                 if strcmpi(btn,'now')
            %                     obj.channelsReadOffsets();
            %                 end
            %             end
	    
        end
        
        function exit(obj)
            fprintf('Exiting ScanImage...\n');
            evalin('base','delete(hSI)');
            evalin('base','clear hSI hSICtl MDF');
            return;
        end
        
        function delete(obj)
            
            if ~strcmp(obj.acqState, 'idle')
                obj.abort();
            end
            
            obj.notify('applicationWillClose');
            
            safeDelete(obj.hTriggerMatrix); % The destructor of hTriggerMatrix access hAcq, needs to be exectued first
            
            safeDelete(obj.hAcq);
            safeDelete(obj.hScan);
            
            delete(obj.hFigs(ishandle(obj.hFigs))); % hFigs is parent to hAxes is parent to hImages. Deleting hFigs deletes its children too            
            delete(obj.hMergeFigs(ishandle(obj.hMergeFigs)));
            
            safeDelete(obj.hLoopRepeatTimer);
            safeDelete(obj.hDisplayRefreshTimer);
            safeDelete(obj.hBeams);         % Beam Object handle.
            safeDelete(obj.hShutters);      % Shutter Object handle.
            safeDelete(obj.hMotors);        % Motor Object handle.
            safeDelete(obj.hFastZ);         % FastZ Object handle.
            safeDelete(obj.hPMTs);          % PMT Object handle.
            safeDelete(obj.hECU1);          % ThorECU1 Object handle.
            safeDelete(obj.hBScope2);       % ThorBScope2 Object handle.
            
            %             % destruct plugins
            %             for i = 1:length(obj.hPlugins)
            %                 hPlugin = obj.hPlugins{i};
            %                 safeDelete(hPlugin);
            %             end
            
            function safeDelete(objHandle)
                % checks if the object exists before deleting it. if error
                % occurs during deconstruction, report error and continue
                if ~isempty(objHandle) && isvalid(objHandle)
                    try
                        delete(objHandle)
                    catch ME
                        most.idioms.reportError(ME);
                    end
                end
            end
        end
        
        function ziniPrepareDisplayFigs(obj)
            
            %Initialize channel figure windows
            %startImageData = zeros(obj.linesPerFrame,obj.pixelsPerLine,obj.channelsDataType);
            for i=1:obj.MAX_NUM_CHANNELS
                obj.hFigs(i) = most.idioms.figureSquare('Name',sprintf('Channel %d',i),...
                    'Visible','off','ColorMap',gray(256),'NumberTitle','off','Menubar','none',...
                    'Tag',sprintf('image_channel%d',i),'CloseRequestFcn',@znstDisplayFigCloseEventHandler);
            end
            obj.hMergeFigs = most.idioms.figureSquare('Name','Channel Merge',...
                'Visible','off','NumberTitle','off','Menubar','none',...
                'Tag','channel_merge','CloseRequestFcn',@znstMergeFigCloseEventHandler);
            
            channelsLUTInitVal = repmat([0 obj.channelsLUTRange(2)],obj.MAX_NUM_CHANNELS,1); %Use unipolar LUT range by default, whether data is signed or not
            obj.zprvResetDisplayFigs(1:obj.MAX_NUM_CHANNELS,true,channelsLUTInitVal);
            
            % register all channel figs with controller
            assert(numel(obj.hController) <= 1); % for now always have a single controller
            if ~isempty(obj.hController)
                ctrler = obj.hController{1};
                for c = 1:obj.MAX_NUM_CHANNELS
                    ctrler.registerGUI(obj.hFigs(c));
                end
                ctrler.registerGUI(obj.hMergeFigs);
            end
            
            function znstDisplayFigCloseEventHandler(src,evnt)
                channelToHide = find(obj.hFigs == src);
                if isempty(channelToHide) %this should never occur
                    set(src,'Visible','off');
                    return
                end
                
                if isempty(find(obj.channelsDisplay==channelToHide, 1))
                    set(src,'Visible','off'); % if the channel is not actively displayed, the window can be closed during an active acquisition
                else
                    obj.zprvAssertIdle('Active channel close'); % if the channel _is_ actively displayed, the window cannot be closed during an active acquisition
                    set(src,'Visible','off');
                    obj.channelsDisplay(obj.channelsDisplay==channelToHide) = [];
                end
            end
            
            function znstMergeFigCloseEventHandler(src,evnt)
                if isvalid(obj)
                    obj.channelsMergeEnable = false;
                else
                    delete(src)
                end
            end
            
        end
        
        
        function ziniPrepareChannels(obj)
            obj.channelOffsets = zeros(obj.MAX_NUM_CHANNELS,1);
        end                
        
    end
    
    
    
    
    
    %% PUBLIC METHODS
    methods
        function startFocus(obj)
            obj.notify('focusStart');
            
            %Set the image figure axes limits
            obj.zzzSetImageFigureAxesLimits();
            obj.zprvResetBuffers();
            
            %Handle auto-channel readoffsets.
            if obj.channelsAutoReadOffsets
                obj.channelsReadOffsets();
            end
            
            %Disable logging directly on the resonant Acq object for Focus
            %only.
            obj.hAcq.loggingEnable = false;
            
            %Set acquisition mode in modules
            %OBSOLETE obj.hAcq.acquisitionMode = 'focus';
            obj.hAcq.framesPerAcquisition = 0; % Focus mode has infinite frames per acquisition
            obj.hAcq.acquisitionsPerAcquisitionMode = 0; % Focus mode has infinite acquisitions per acquisition mode.
            
            obj.frameCounter = 0;
            obj.frameCounterDisplay = 0;
            obj.frameCounterLastAcq = 0;
            obj.loopAcqCounter = 0;
            obj.overvoltageStatus = false;
            
            %Open shutters for focusing.
            obj.hShutters.shuttersTransition(true);
            
            %TODO: Handle 'calibrate frequency' outside of startFocus()
            %obj.hScan.resonantScannerActivate(true);
            %obj.hScan.resonantScannerWaitSettle();
            %resFreq = obj.hScan.calibrateResonantScannerFreq();
            %obj.resonantScannerFreq = resFreq;
            %obj.hAcq.scannerFrequency = resFreq;
            %obj.periodClockPhase = obj.hAcq.estimatedPhaseTriggerDelay;
            %fprintf('Scanner Frequency calibrated: %fHz\n',resFreq);
            
            %Start PMTs adapter
            obj.hPMTs.start();
            
            %Start beams task.
            obj.hBeams.hBeamsTask.start();
            
            %Reset Buffers for Frame Averaging (this is done in SI4.2)
            obj.zprvResetBuffers();
            obj.zprvResetHome();
            
            obj.hScan.start();
            obj.hAcq.start();
            
            %The following command actually issues the software trigger.
            obj.hAcq.generateSoftwareAcqTrigger();

            %Reset Frames Per Stack
            obj.hAcq.framesPerStack = 0;
            
            %Set the start time of the focus.
            [obj.acqStartTime, obj.acqModeStartTime] = deal(clock());
                        
            start(obj.hLoopRepeatTimer);
            start(obj.hDisplayRefreshTimer);
            
            obj.secondsCounter = 0;
            
            obj.acqMode = 'focus';
            obj.acqState = 'focus';
        end
        
        function startGrab(obj)
            %Disable direct mode if beams enabled.
            if obj.hBeams.beamNumBeams > 0 && obj.beamDirectMode && obj.stackNumSlices > 1
                obj.zprvSetInternal('beamDirectMode', false); % This resets beam task if needed
            end
            
            %Tell Acquisition object how many frames to grab.
            obj.hAcq.framesPerAcquisition = obj.acqNumFramesPerTrigger;
            if obj.stackNumSlices > 1 && ~obj.fastZEnable
                % slow stack
                obj.hAcq.acquisitionsPerAcquisitionMode = obj.stackNumSlices;
            else
                obj.hAcq.acquisitionsPerAcquisitionMode = 1;
            end
            
            
            %Disable external triggering on slow stacks only.
            if obj.stackNumSlices > 1 && ~obj.fastZEnable
                obj.triggerTypeExternal = false;
            end
            
            %Read digitizer voltage offsets, if needed
            if obj.channelsAutoReadOffsets
                obj.channelsReadOffsets();
            end
            
            obj.acqMode = 'grab';
            obj.acqState = 'grab';
            zzzStartAcquisitionMode(obj);
        end
        
        function startLoop(obj)
            %Set the image figure axes limits
            %             obj.zzzSetImageFigureAxesLimits();
            
            %Set acquisition mode in modules
            %obj.hAcq.acquisitionMode = 'loop';
            %Tell Acquisition object how many frames to grab.
            obj.hAcq.framesPerAcquisition = obj.acqNumFramesPerTrigger;
            
            if obj.stackNumSlices > 1 && ~obj.fastZEnable
                % slow stack
                obj.hAcq.acquisitionsPerAcquisitionMode = obj.stackNumSlices * obj.acqsPerLoop;
            else
                obj.hAcq.acquisitionsPerAcquisitionMode = obj.acqsPerLoop;
            end
            
            %Read Frame Grabber Input voltage offsets, if needed
            if obj.channelsAutoReadOffsets
                obj.channelsReadOffsets();
            end
            
            obj.acqMode = 'loop';
            obj.acqState = 'loop';
            zzzStartAcquisitionMode(obj);
            
        end
        
        function abort(obj)
            obj.notify('acqAbort');
            acqStateCache = obj.acqState;
            
            obj.zzzShutdown();
            
            if strcmpi(acqStateCache,'focus')
                obj.notify('focusDone');
                obj.setClassDataVar('scanPhaseMap',obj.scanPhaseMap);
            end
        end
    end
    
    %% PUBLIC METHODS FROM 4.2
    methods
        function scannerPeriodMeasure(obj)
            %Measure scanner period at current zoomFactor. Required before
            %Grab/Loop acquisition can be started for any set of values.
            assert(strcmpi(obj.acqState,'idle'),'ScanImage must be in ''idle'' state to measure scan frame period');
            
            wasScannerActive = obj.hScan.resonantScannerActive;
            obj.hScan.resonantScannerActivate(true);
            obj.hScan.resonantScannerWaitSettle(2); % assumption: the scanner frequency should be settled after 2 seconds
            resFreq = obj.hScan.calibrateResonantScannerFreq();
            obj.hScan.resonantScannerActivate(wasScannerActive);
            
            obj.resonantScannerFreq = resFreq;
            obj.hAcq.scannerFrequency = resFreq;
            
            fprintf('Scanner Frequency calibrated: %fHz\n',resFreq);
            obj.hScan.resonantScannerActivate(false);
        end
        
        function scanPointBeam(obj,beams)
            %Points scanner at center of FOV, opening shutter and with specified beams ON
            
            % SYNTAX
            %   beams: <Optional> Specifies which beams to turn ON. If omitted, all beams are turned ON.
            
            assert(strcmpi(obj.acqState,'idle'),'Unable to complete specified operation in current acquisition state (''%s'')',obj.acqState);
            
            obj.hScan.centerGalvo();
            %obj.hScan.galvoParkDeg = 0;
            %             if obj.galvoEnable
            %                 obj.hGalvos.control('DAQmx_Val_Task_Unreserve');
            %                 obj.hGalvosPark.writeAnalogData(repmat(0,1,numel(obj.mdfData.galvoChanIDs)));
            %             end
            obj.hBeams.beamsOn(); %TODO: beamsOn() should be able to operate on specified beam subset
            obj.hShutters.shuttersTransition(true);
            
            obj.acqState = 'point';
        end
    end
    
    
    %% HIDDEN METHODS
    methods (Hidden)
        function zzzSetImageFigureAxesLimits(obj)
            if ~isempty(obj.channelsDisplay)
                hImages_ = obj.hImages{obj.channelsDisplay};
                for i=1:numel(obj.channelsDisplay)
                    figure(obj.hFigs(obj.channelsDisplay(i)));
                    set(obj.hFigs(obj.channelsDisplay(i)),'HandleVisibility','callback');
                end
                
                for i=1:numel(hImages_)
                    if ~isempty(get(hImages_(i),'Parent'))
                        hAx = get(hImages_(i),'Parent');
                        %hAx = hImages_(i);
                        set(hAx,    'XLim',[1 obj.pixelsPerLine],...
                            'YLim',[1 obj.linesPerFrame]);
                        
                        set(hImages_(i),'CData',zeros(obj.linesPerFrame,obj.pixelsPerLine));
                    end
                end
            end
        end
        
        function zzzStartAcquisitionMode(obj)
            notify(obj,'acqModeStart');
            
            obj.hAcq.loggingEnable = obj.loggingEnable;
            if obj.loggingEnable                
                if obj.zprvValidateLoggingFile()
                    obj.hAcq.loggingHeaderString = obj.modelGetHeader();
                else
                    obj.abort();
                    return;
                end
            end
            
            %Common code for starting GRAB and LOOP modes

            %If FastZ, tell FPGA that how many Slices to capture per stack
            if obj.fastZEnable
                obj.hAcq.framesPerStack = obj.fastZNumFramesPerVolume;
            else
                obj.hAcq.framesPerStack = 0;
            end
            
            obj.loopAcqCounter = 0;
            obj.frameCounterLastAcq = 0;
            obj.overvoltageStatus = false;
            %Set the image figure axes limits
            obj.zzzSetImageFigureAxesLimits();
            obj.zprvResetBuffers();
            %Force first frame of first acquisition to notify AcqStart
            %trigger.
            obj.endOfAcquisitionFlag = true;
            
            
            %Set the start time of the grab.
            [obj.acqStartTime, obj.acqModeStartTime] = deal(clock());
            
            obj.hLoopRepeatTimer.TasksToExecute = Inf;
            obj.hDisplayRefreshTimer.TasksToExecute = Inf;
            
            %TODO: Handle 'calibrate frequency' outside of startFocus()
            %obj.hScan.resonantScannerActivate(true);
            %obj.hScan.resonantScannerFreqSettle();
            %resFreq = obj.hScan.calibrateResonantScannerFreq();
            %obj.resonantScannerFreq = resFreq;
            %obj.hAcq.scannerFrequency = resFreq;
            %obj.periodClockPhase = obj.hAcq.estimatedPhaseTriggerDelay;
            %fprintf('Scanner Frequency calibrated: %fHz\n',resFreq);
            
            %Common code for start GRAB and individual LOOP Repeat
            %Set Acquisition Mode
            obj.acqState = obj.acqMode;
            
            %Configure multi-slice acquisition, as needed
            obj.zprvResetAcqCounters(); %Resets /all/ counters
            obj.zprvResetHome(); %Reset motor/fastZ/beam positions/powers
            obj.zprvInitializeMultiSliceMotorsAndBeams();
            
            %Start Loop and Display Refresh Repeat timers
            start(obj.hLoopRepeatTimer);
            start(obj.hDisplayRefreshTimer);
            if ismember(obj.acqState,{'grab'}) || (ismember(obj.acqState,{'loop','loop_wait'}) && obj.triggerTypeExternal)
                obj.secondsCounter = 0;
            else
                obj.secondsCounter = obj.loopAcqInterval;
            end
            
            %Open shutters for acquisition (if they are enabled)
            obj.hShutters.shuttersTransition(true,true);
            
            %Start beams task.
            obj.hBeams.hBeamsTask.start();
            
            %Start PMTs adapter
            obj.hPMTs.start();
            
            %Start acquisition & scanning
            obj.hScan.start();
            obj.hAcq.start();
            
            %Handle the case where external triggering is off for GRAB and LOOP
            if ismember(obj.acqState,{'grab' 'loop'}) && ~obj.triggerTypeExternal
                obj.hAcq.generateSoftwareAcqTrigger(); % ignored if obj.hAcq.triggerTypeExternal == true
            end
        end
        
        function zzzShutdown(obj)
            
            try
                obj.hPMTs.abort();
            catch ME
                most.idioms.reportError(ME);
            end
            
            try
                obj.hScan.stop();
            catch ME
                most.idioms.reportError(ME);
            end
            
            try
                obj.hAcq.abort();
                
                %Set the framelogger to the default mode of creating a new file on each acq.
                obj.hAcq.loggingSlowStack = false;
            catch ME
                most.idioms.reportError(ME);
            end
            
            %Close shutters for stop acquisition.
            obj.hShutters.shuttersTransition(false);
            
            %Set beams to standby mode for next acquisition.
            try
                obj.hBeams.beamsStandby();
            catch ME
                most.idioms.reportError(ME);
            end
            
            
            try
                %Stop the loop repeat timer.
                stop(obj.hLoopRepeatTimer);
                
                %Stop the display refresh timer.
                stop(obj.hDisplayRefreshTimer);
            catch ME
                most.idioms.reportError(ME);
            end
            
            try
                %Wait for any pending moves to finish.
                if (obj.hMotors.motorHasMotor)
                    moveWaitForFinish(obj.hMotors.stackZMotor);
                end
                
                %Move all motors to home position.
                obj.zprvGoHome();
                obj.notify('motorPositionUpdate');
            catch ME
                most.idioms.reportError(ME);
            end
            
            try
                %Stop Beams Task
                obj.hBeams.hBeamsTask.stop();
            catch ME
                most.idioms.reportError(ME);
            end
            
            %Change the acq State to idle.
            obj.acqState = 'idle';
        end
        
        function zzzEndOfAcquisitionMode(obj)
            notify(obj,'acqModeDone');
                                    
            %Perform frame number accounting
            obj.frameCounterLastAcq = obj.frameCounter;
            
            %This function is called at the end of FOCUS, GRAB, and LOOP acquisitions.
            obj.loopAcqCounter = obj.loopAcqCounter + 1;
            
            %Update logging file counters for next Acquisition
            if obj.loggingEnable
                obj.loggingFileCounter = obj.loggingFileCounter + 1;
            end
            
            %Reset the endOfAcquisitionFlag to false.
            obj.endOfAcquisitionFlag = false;
            
            obj.zzzShutdown();
        end
        
        function zzzEndOfAcquisition(obj)
            notify(obj,'acqDone');
            
            %Set the endOfAcquisitionFlag
            obj.endOfAcquisitionFlag = true;
            
            %Perform frame number accounting
            obj.frameCounterLastAcq = obj.frameCounter;
            
            if obj.stackSlicesDone < obj.stackNumSlices && obj.stackNumSlices > 1 && ~obj.fastZEnable
                %**********************************************************
                %BEGIN IN-PROGRESS SLOW STACK ACQUISITION CODE.
                %**********************************************************
                %For in-progress multi-slice acquisitions, continue to loop
                %**********************************************************
                %Close shutters for move - only if the user has not enabled shutterHoldOpenOnStack
                if ~obj.shutterHoldOpenOnStack
                    obj.hShutters.shuttersTransition(false);
                end
                
                %Adjust beam power to account for depth.
                obj.hBeams.zprvBeamsDepthPowerCorrection(obj.stackZStepSize,obj.hBeams.acqBeamLengthConstants);
                
                %Block on motor move to next z position.
                if (obj.hMotors.motorHasMotor)
                    try
                        moveWaitForFinish(obj.hMotors.stackZMotor);
                    catch ME
                        fprintf(2,[ME.message '\n']);
                    end
                    obj.notify('motorPositionUpdate'); %Signal potential motor position update
                else
                    warning('Attempted Z-stage move for Slow Stack, but no motor configured.');
                end
                
                %Start beams task.
                obj.hBeams.hBeamsTask.start();
                
                %Open shutters immediately after move completes.
                if ~obj.shutterHoldOpenOnStack
                    obj.hShutters.shuttersTransition(true,true);
                end
                
                %Start next slice.
                obj.hAcq.generateSoftwareAcqTrigger();
            else
                if obj.stackNumSlices > 1 && ~obj.fastZEnable
                    %Handle end of slow stack case:
                    %Move all motors to home position.
                    obj.zprvGoHome();
                    obj.notify('motorPositionUpdate');
                end

                if ~obj.fastZEnable
                    %Initialize slow stack motor commands for next slice.
                    obj.zprvInitializeMultiSliceMotors();
                end
                
                %Handle end of GRAB or LOOP Repeat
                obj.loopAcqCounter = obj.loopAcqCounter + 1;
                
                %Update logging file counters for next Acquisition
                if obj.loggingEnable
                    obj.loggingFileCounter = obj.loggingFileCounter + 1;
                end
                
                %Set slow stack is as disarmed.
                obj.stackSlowArmed = false;
                
                %For Loop, restart or re-arm acquisition
                if isequal(obj.acqMode,'loop')
                    if obj.loopAcqCounter < obj.acqsPerLoop
                        %If not in externally triggered mode, close the shutter.
                        if ~obj.triggerTypeExternal
                            obj.hShutters.shuttersTransition(false);
                        end
                        obj.acqState = 'loop_wait';
                    end
                else
                    obj.zzzShutdown();
                end
            end
        end
        
        function frame = data2frame(obj, data)
            frame = reshape(data,obj.pixelsPerLine,obj.linesPerFrame)';
        end
        
        function estimatedPhase = zzzEstimatePeriodClockPhase2(obj,updatehAcq)
            updateAcq = nargin < 2 || isempty(updatehAcq) || updatehAcq;
            if ~isa(obj.scanPhaseMap,'containers.Map')
                fprintf('Warning: EstimatePeriodClockPhase2 called while scanPhaseMap was empty.\n');
                return
            end
            
            scanPhaseMapArray = cell2mat(keys(obj.scanPhaseMap));
            
            if ismember(obj.zoomFactor, scanPhaseMapArray)
                %If the zoom factor is a key in the scanPhaseMap, simply return its value.
                value = obj.scanPhaseMap(obj.zoomFactor);
            else
                %If the zoom factor is not a key in the scanPhaseMap, then
                %interpolate (or extrapolate) value from its nearest
                %neighbors.
                if isempty(keys(obj.scanPhaseMap))
                    value = 0; %If there are no keys in the phase map, then default to zero.
                else
                    %Find the first key below this zoom level.
                    lowKey = scanPhaseMapArray(find(obj.zoomFactor>scanPhaseMapArray,1,'last'));
                    %Find the first key above this zoom level.
                    highKey = scanPhaseMapArray(find(obj.zoomFactor<scanPhaseMapArray,1,'first'));
                    if isempty(lowKey)
                        %If there is no key with a lower zoomFactor than
                        %the current one, return the value corresponding to
                        %the next lower known zoomFactor.
                        value = obj.scanPhaseMap(highKey);
                    elseif isempty(highKey)
                        %If there is no key with a higher zoomFactor than
                        %the current one, return the value corresponding to
                        %the next higher known zoomFactor.
                        value = obj.scanPhaseMap(lowKey);
                    else
                        %The usual case: There is a defined phase for
                        %zoomFactors greater than and less than the current
                        %one.
                        switch obj.scanPhaseMode
                            case 'Next Lower'
                                value = obj.scanPhaseMap(lowKey);
                            case 'Next Higher'
                                value = obj.scanPhaseMap(highKey);
                            case 'Nearest Neighbor'
                                if (highKey - obj.zoomFactor) > (obj.zoomFactor - lowKey)
                                    value = obj.scanPhaseMap(lowKey);
                                else
                                    value = obj.scanPhaseMap(highKey);
                                end
                            case 'Interpolate'
                                uniqueKeyVals = unique(linspace(lowKey,highKey));
                                
                                value = interp1(uniqueKeyVals, ...
                                    linspace(obj.scanPhaseMap(lowKey), ...
                                    obj.scanPhaseMap(highKey),numel(uniqueKeyVals)),obj.zoomFactor);
                            otherwise
                        end
                    end
                end
            end
            
            estimatedPhase = round(value);
            
            if updateAcq
                obj.periodClockPhase = estimatedPhase;
            end
        end
        
        %         function estimatedPhase = zzzEstimatePeriodClockPhase(obj,updatehAcq)
        %             updateAcq = nargin < 2 || isempty(updatehAcq);
        %
        %             empiricalVolts = [4.950000,3.96,3,2.475000,1.650000,1.237500,0.990000,0.825000,0.707143,0.618750,0.550000];
        %             empiricalPixelsPerLine = [256 512 1024 2048];
        %
        %             empiricalPhase =  ...
        %               [ 0.5500    0.7000    0.9750    1.2125    1.6000    1.7625    1.9125    1.9750    2.0625    2.1000    2.1250
        %                 0.5875    0.7375    1.0125    1.2250    1.6125    1.8000    1.9375    2.0250    2.1000    2.1250    2.1875
        %                 0.5875    0.7500    1.0375    1.2625    1.6500    1.8375    1.9625    2.0375    2.1250    2.1750    2.1875
        %                 0.5875    0.7500    1.0375    1.2625    1.6625    1.8625    1.9625    2.0875    2.1750    2.1875    2.2125 ];
        %             %surf(empiricalVolts,empiricalPixelsPerLine,empiricalPhase)
        %
        %             obj.hScan.resonantScannerRangeVolts
        %
        %             estimatedPhase = interp2(empiricalVolts,empiricalPixelsPerLine,empiricalPhase,...
        %                 obj.hScan.resonantScannerRangeVolts,obj.pixelsPerLine,'linear',-1)
        %
        %             if estimatedPhase < 0
        %                 % no empirical data in this range
        %                 return
        %             end
        %
        %             if updateAcq
        %                 obj.periodClockPhase = estimatedPhase * obj.hAcq.sampleRate / 1e6;
        %             end
        %         end
    end
    
    %% Callbacks
    methods (Hidden)
        function zzzFrameAcquiredFcn(obj,~,~)
            %**************************************************************
            %ACQUISITION
            %**************************************************************
            %If not acquiring frames, then do nothing.
            if ~obj.hAcq.acqRunning
                return;
            end
            processFrameBatch = true;
            %**************************************************************
            %GET FRAME DATA FROM IMAGE CAPTURE DEVICE
            %**************************************************************
            %Append data acquired from acquisition device to end of frame buffer.
            %**************************************************************
            while processFrameBatch
                [obj.acqFrameBuffer{end},fpgaFrameNumberAcqMode_,acqFlags,elremaining,FramesRemaining] = obj.hAcq.readFrame();

                obj.fpgaFrameNumberAcqMode = fpgaFrameNumberAcqMode_;
                obj.acqFrameNumberBuffer{end} = obj.fpgaFrameNumberAcqMode;
                receivedFrameNumber = obj.fpgaFrameNumberAcqMode;
                
                if obj.fpgaFrameNumberAcqMode == 1
                    % start of acquisition mode
                    obj.fpgaFrameNumberAcq = 1;
                    obj.fpgaLastEndOfAcquisition = 0;
                    obj.fpgaAcqCounter = 0;
                end
                
                obj.fpgaFrameNumberAcq = obj.fpgaFrameNumberAcqMode - obj.fpgaLastEndOfAcquisition;
                
                if acqFlags.endOfAcquisition
                    obj.fpgaLastEndOfAcquisition = obj.fpgaFrameNumberAcqMode;  
                    obj.fpgaAcqCounter = obj.fpgaAcqCounter + 1;
                end
                
                % Stop processing frames once the number of frames remaining in
                % this batch is zero.
                if FramesRemaining <= 0 || obj.displayBatchingFactor <= 1
                    processFrameBatch = false;
                end
                
                if ~obj.multiChannel
                    if ~isempty(obj.channelsDisplay)
                        activeSingleChannel = obj.channelsDisplay(1);
                        obj.acqFrameBuffer{end}{activeSingleChannel} = obj.acqFrameBuffer{end}{1};
                    end
                end
                assert(~isempty(obj.acqFrameBuffer{end}),'Got empty frame data');
                
                %Circular permutation so that first element is most-recent frame
                %TODO: Handle missed frames
                obj.acqFrameBuffer = [obj.acqFrameBuffer(end);obj.acqFrameBuffer(1:end-1)];
                obj.acqFrameNumberBuffer = [obj.acqFrameNumberBuffer(end);obj.acqFrameNumberBuffer(1:end-1)];
                
                %**********************************************************
                %HANDLE OVER-VOLTAGE CONDITION IF DETECTED.
                %**********************************************************
                if acqFlags.overvoltage && ~obj.overvoltageStatus % Only fire this event once
                    obj.notify('overvoltage');
                    obj.overvoltageStatus = true;
                end
                
                %**********************************************************
                %HANDLE ACCOUNTING FOR FIRST FRAME OF ACQUISITION
                %**********************************************************
                if isequal(obj.acqMode,'loop') && isequal(obj.acqState,'loop_wait') && obj.loopAcqCounter < obj.acqsPerLoop
                    %Change acquisition state to 'loop' if we were in a 'loop_wait' mode.
                    obj.acqState = 'loop';
                    %Handle slow stack case.
                    if obj.stackNumSlices > 1 && ~obj.fastZEnable
                        obj.zprvResetAcqCounters();
                    end
                end
                
                focusingNow = strcmpi(obj.acqState,'focus');
                fastZAcq = obj.fastZEnable && obj.stackNumSlices > 1 && ~focusingNow;
                
                if obj.endOfAcquisitionFlag
                    %Reset counters if this is the first frame of an acquisition.
                    obj.notify('acqStart');
                    obj.frameCounter = receivedFrameNumber;
                    obj.frameCounterDisplay = receivedFrameNumber - obj.frameCounterLastAcq;
                    obj.endOfAcquisitionFlag = false;
                    
                    %Only reset countdown timer if we are not currently in
                    %a slow stack grab.
                    if ~obj.hAcq.loggingSlowStack
                        obj.acqStartTime = clock();
                        
                        if ismember(obj.acqState,{'grab'}) || (ismember(obj.acqState,{'loop','loop_wait'}) && obj.triggerTypeExternal)
                            obj.secondsCounter = 0;
                        else
                            obj.secondsCounter = obj.loopAcqInterval;
                        end
                    end
                else
                    %Otherwise, just increment the frame counter.
                    obj.frameCounter = receivedFrameNumber;
                    obj.frameCounterDisplay = receivedFrameNumber - obj.frameCounterLastAcq;
                end
                
                %**********************************************************
                %ALL OTHER PROCESSING
                %**********************************************************
                %MOTOR MOVEMENT FOR SLOW STACK ACQUISITION
                %**********************************************************
                %Stop acquisition and start motor move to next slice, as needed
                %fprintf('acquisition in Z: focusingNow: %d, obj.fastZEnable: %d, obj.stackNumSlices: %d, obj.frameCounter: %d, obj.acqNumFrames: %d\n',focusingNow, obj.fastZEnable, obj.stackNumSlices, obj.frameCounter, obj.acqNumFrames);
                %**********************************************************
                if ~focusingNow && ~obj.fastZEnable && obj.stackNumSlices > 1 && obj.frameCounterDisplay >= obj.acqNumFrames
                    %Handle slow stack operations here.
                    if abs(obj.stackZStepSize) > obj.stackShutterCloseMinZStepSize && ~obj.shutterHoldOpenOnStack
                        obj.hShutters.shuttersTransition(false);
                    end
                    
                    obj.notify('sliceDone');
                    
                    obj.stackSlicesDone = obj.stackSlicesDone + 1;
                    
                    if obj.stackSlicesDone < obj.stackNumSlices
                        pos = obj.hMotors.stackZMotor.positionRelative;
                        pos(3) = obj.stackRefZPos + obj.stackZStepSize*obj.stackSlicesDone;
                        obj.hMotors.stackZMotor.moveStartRelative(pos);
                    end
                end
                
                %**********************************************************
                %UPDATE FASTZ BEAM DATA (IF REQUIRED)
                %**********************************************************
                if fastZAcq && obj.fastZAllowLiveBeamAdjust && (obj.beamFlybackBlanking || obj.beamPzAdjust)
                    obj.hBeams.zprvBeamsRefreshFastZData(obj,1);
                end
                
                %**********************************************************
                %FRAME AVERAGING / FRAME SELECTION FEATURES (IF REQUIRED)
                %**********************************************************
                %Identify current frame within the acquisition frame buffer
                %**********************************************************
                frameBatchIdx = mod(obj.frameCounter-1,obj.displayFrameBatchFactor) + 1;
                [displayTF, tileIdx] = ismember(frameBatchIdx,obj.displayFrameBatchSelection);
                if displayTF
                    %Handle averaging, as needed
                    %Note that if any frames were missed, then the rolling average will now simply stretch back further in time
                    %A different behavior might be preferable, but probably not worth complicating logic significantly for a hopefully rare case
                    rollAveFactor = obj.displayRollingAverageFactor;
                    if rollAveFactor > 1 %Display averaging enabled
                        selectedFramesDone = ceil(obj.frameCounter/obj.displayFrameBatchFactor); %TODO: obj.frameCounter used here instead of framesAcquiredTotal - is that correct?
                        if selectedFramesDone == 1
                            %****************
                            %FIRST FRAME CASE
                            %****************
                            obj.displayRollingBuffer{tileIdx} = cellfun(@(x) double(x),obj.acqFrameBuffer{1},'un',0);
                        elseif selectedFramesDone <= rollAveFactor
                            %**********************
                            %NEXT (n-1) FRAMES CASE
                            %**********************
                            for i=1:obj.MAX_NUM_CHANNELS
                                if ismember(i,obj.channelsDisplay)
                                    obj.displayRollingBuffer{tileIdx}{i} = ((selectedFramesDone - 1) * obj.displayRollingBuffer{tileIdx}{i} + double(obj.acqFrameBuffer{1}{i})) / selectedFramesDone;
                                end
                            end
                        else
                            %*********************
                            %ALL SUBSEQUENT FRAMES
                            %*********************
                            removeIdx = obj.displayRollingAverageFactor * (obj.displayFrameBatchFactor / obj.frameAcqFcnDecimationFactor) + 1;
                            if removeIdx <= numel(obj.acqFrameBuffer)
                                if ~isempty(obj.acqFrameBuffer{removeIdx})
                                    for i=1:obj.MAX_NUM_CHANNELS
                                        if ismember(i,obj.channelsDisplay)
                                            %The following check must be made to handle the case where
                                            %asynchronous user events cause the value of buffers to change
                                            %while the frame display function is executing.
                                            if i <= numel(obj.displayRollingBuffer{tileIdx}) && i <= numel(obj.acqFrameBuffer{1}) && i <= numel(obj.acqFrameBuffer{removeIdx})
                                                obj.displayRollingBuffer{tileIdx}{i} = obj.displayRollingBuffer{tileIdx}{i} + ( double(obj.acqFrameBuffer{1}{i}) - double(obj.acqFrameBuffer{removeIdx}{i}) ) / rollAveFactor;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                %**********************************************************
                %UPDATE FRAME COUNTERS
                %**********************************************************
                %TODO: Make this logic work with resonantAcq logging.
                framesDoneSinceFileBreak = obj.fpgaFrameNumberAcq;
                
                if ~focusingNow && obj.fastZEnable
                    framesPerVolume = obj.fastZNumFramesPerVolume;
                    
                    obj.fastZVolumesDone = floor(framesDoneSinceFileBreak/framesPerVolume);
                    obj.stackSlicesDone = min((framesDoneSinceFileBreak - obj.fastZVolumesDone * framesPerVolume)/obj.acqNumFrames, obj.stackNumSlices);
                    obj.acqFramesDone = min(framesDoneSinceFileBreak - obj.stackSlicesDone * obj.acqNumFrames, obj.acqNumFrames);
                    
                    % In the FastZ case, the frameCounterLastAcq should
                    % always be 1.
                    obj.frameCounterLastAcq = obj.frameCounter;
                else
                    obj.acqFramesDone = framesDoneSinceFileBreak;
                end
                
                %**********************************************************
                %REQUEST PMT STATUS UPDATE
                %**********************************************************
                for i = 1:numel(obj.hPMTs.hPmtControllers)
                    updateTime = toc(obj.hPMTs.hPmtControllers{i}.pmtsStatusLastUpdated);
                    if updateTime > obj.hPMTs.hPmtControllers{i}.acqStatusUpdateInterval
                        obj.hPMTs.hPmtControllers{i}.pmtsUpdateStatus();
                    end
                end
                
                obj.notify('frameAcquired');
                %**********************************************************
                %ACQUISITION MODE SPECIFIC BEHAVIORS
                %**********************************************************
                switch obj.acqState
                    case 'focus'
                        if etime(clock, obj.acqStartTime) >= obj.focusDuration
                            obj.zzzEndOfAcquisition();
                            break;
                        end
                    case {'grab' 'loop'}
                        %Handle signals from FPGA
                        if acqFlags.endOfAcquisitionMode
                            obj.zzzEndOfAcquisitionMode();
                            break;
                        elseif acqFlags.endOfAcquisition
                            obj.zzzEndOfAcquisition();
                            break;
                        end
                    case {'idle'}
                        %Do nothing...should this be an error?
                end
            end
        end
        
        function zzzLoopTimerFcn(obj,src,~)
            obj.zprvUpdateSecondsCounter();
            % *************************************************************
            % BEGIN SPECIAL PROCESSING FOR SOFTWARE TRIGGERED ACQUISITIONS
            % *************************************************************
            if ~obj.triggerTypeExternal && ismember(obj.acqState,{'loop_wait'});
                %Slow stack arming step:
                %   Open the shutter a second before generating the software acq trigger.
                %   Only do this if the slow stack is not armed.
                if floor(obj.secondsCounter) <= 1 && ~obj.stackSlowArmed
                    obj.hBeams.hBeamsTask.stop();
                    obj.hBeams.hBeamsTask.start();
                    obj.hShutters.shuttersTransition(true,true);
                    obj.stackSlowArmed = true;
                end
                
                %When the timer reaches zero and arming has been completed
                %generate a software trigger and reset the timer.
                if floor(obj.secondsCounter) <= 0 && obj.stackSlowArmed
                    obj.hAcq.generateSoftwareAcqTrigger();
                    stop(src);                    
                    obj.acqStartTime = clock();                    
                    start(src);
                    obj.secondsCounter = obj.loopAcqInterval;
                end
            elseif obj.secondsCounter == 0
                warning('Software timer went to zero during active loop. Waiting until end of current acq before issuing software trigger.');
            end
            % *************************************************************
            % *************************************************************
            % *************************************************************
        end
        
        function zzzFrameDisplayFcn(obj,src,~)
            %Handle display, if frame is selected for display
            chansToDisp = obj.channelsDisplay;
            %if mod(obj.acqFrameNumberBuffer{1},obj.displayFrameBatchFactor) == batchFactor
            %for tileIdx=1:obj.displayFrameBatchFactor
            tileIdx = mod(obj.acqFrameNumberBuffer{1} - 1,obj.displayFrameBatchFactor) + 1;
            if ~isempty(obj.displayFrameBatchSelection) && obj.displayLastFrameDisplayed ~= obj.acqFrameNumberBuffer{1} && obj.acqFrameNumberBuffer{1} > 0 && ismember(tileIdx,obj.displayFrameBatchSelection)
                obj.displayLastFrameDisplayed = obj.acqFrameNumberBuffer{1};
                
                %NOTE: tiled displays experience undersampling at large #'s of
                %tiled frames.
                abortUpdate = false;
                for i=1:length(chansToDisp)
                    chanIdx=chansToDisp(i);
                    
                    hChan = obj.hImages{chanIdx};
                    hTxt = obj.hText{chanIdx};
                    
                    [~,displayTileIdx] = ismember(tileIdx,obj.displayFrameBatchSelection);
                    
                    if (displayTileIdx <= numel(hChan)) && ~ishandle(hChan(displayTileIdx))
                        abortUpdate = true;
                        break;
                    end
                    
                    if obj.mroiEnabled
                        zprvMultiROIDisplayFcn(obj,hChan(tileIdx),tileIdx,i);
                    else
                        if obj.displayRollingAverageFactor > 1
                            if tileIdx <= numel(obj.displayRollingBuffer) && tileIdx <= numel(hChan)
                                if chanIdx <= numel(obj.displayRollingBuffer{tileIdx})
                                    set(hChan(tileIdx),'CData',obj.displayRollingBuffer{tileIdx}{chanIdx}); %There is no need to convert this to type spec'd by obj.channelsDataType
                                    if obj.debugFrameNumbers
                                        set(hTxt(tileIdx),'String',obj.acqFrameNumberBuffer{1});
                                    end
                                end
                            end
                        else
                            if displayTileIdx <= numel(hChan) && chanIdx <= numel(obj.acqFrameBuffer{1})
                                set(hChan(displayTileIdx),'CData',obj.acqFrameBuffer{1}{chanIdx});
                                if obj.debugFrameNumbers
                                    set(hTxt(displayTileIdx),'String',obj.acqFrameNumberBuffer{1});
                                end
                            end
                        end
                    end
                end
                
                if ~abortUpdate
                    zprvUpdateMergeWindowIfNecessary(obj,tileIdx);
                end
            end
        end
        
        function zzzFrameDisplayFcn2(obj,src,~)
            %This version of the frame display function will display frames
            %in batches of n, where n is the displayFrameBatchFactor.
            %Handle display, if frame is selected for display
            chansToDisp = obj.channelsDisplay;
            if mod(obj.acqFrameNumberBuffer{1},obj.displayFrameBatchFactor) == 0
                if obj.displayLastFrameDisplayed ~= obj.acqFrameNumberBuffer{1}
                    obj.displayLastFrameDisplayed = obj.acqFrameNumberBuffer{1};
                    % Only loop through the numbers of tiles we are displaying.
                    for tileIdx=1:numel(obj.displayFrameBatchSelection)
                        abortUpdate = false;
                        for i=1:length(chansToDisp)
                            chanIdx=chansToDisp(i);
                            
                            hChan = obj.hImages{chanIdx};
                            hTxt = obj.hText{chanIdx};
                            
                            if numel(hChan) < tileIdx || ~ishandle(hChan(tileIdx))
                                abortUpdate = true;
                                break;
                            end
                            
                            if obj.mroiEnabled
                                zprvMultiROIDisplayFcn(obj,hChan(tileIdx),tileIdx,i);
                            else
                                if obj.displayRollingAverageFactor > 1
                                    if tileIdx <= numel(obj.displayRollingBuffer) && tileIdx <= numel(hChan)
                                        if chanIdx <= numel(obj.displayRollingBuffer{tileIdx})
                                            set(hChan(tileIdx),'CData',obj.displayRollingBuffer{tileIdx}{chanIdx}); %There is no need to convert this to type spec'd by obj.channelsDataType
                                            if obj.debugFrameNumbers
                                                set(hTxt(tileIdx),'String',obj.acqFrameNumberBuffer{obj.displayFrameBatchFactor - obj.displayFrameBatchSelection(tileIdx) + 1});
                                            end
                                        end
                                    end
                                else
                                    if tileIdx <= numel(hChan) && chanIdx <= numel(obj.acqFrameBuffer{1})
                                        if (obj.displayFrameBatchFactor - obj.displayFrameBatchSelection(tileIdx) + 1 < numel(obj.acqFrameBuffer))
                                            if ~isempty(obj.acqFrameBuffer{obj.displayFrameBatchFactor - obj.displayFrameBatchSelection(tileIdx) + 1})
                                                set(hChan(tileIdx),'CData',obj.acqFrameBuffer{obj.displayFrameBatchFactor - obj.displayFrameBatchSelection(tileIdx) + 1}{chanIdx});
                                                if obj.debugFrameNumbers
                                                    set(hTxt(tileIdx),'String',obj.acqFrameNumberBuffer{obj.displayFrameBatchFactor - obj.displayFrameBatchSelection(tileIdx) + 1});
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        if ~abortUpdate
                            zprvUpdateMergeWindowIfNecessary(obj,tileIdx);
                        end
                    end
                end
            end
        end
    end
    
    %% STATIC/HIDDEN METHODS (Channel Merge)
    methods (Static,Hidden)
        function mergeData = zprvAddChanDataToMergeData(mergeData,chanData,clr,lut)
            range = lut(2)-lut(1);
            chanDataRescaled = uint8(double(chanData-lut(1))/range * 255);
            switch clr
                case 'red'
                    mergeData(:,:,1) = mergeData(:,:,1) + chanDataRescaled;
                case 'green'
                    mergeData(:,:,2) = mergeData(:,:,2) + chanDataRescaled;
                case 'blue'
                    mergeData(:,:,3) = mergeData(:,:,3) + chanDataRescaled;
                case 'gray'
                    mergeData(:,:,:) = mergeData(:,:,:) + repmat(chanDataRescaled,[1 1 3]);
                case 'none'
                    % no-op
                otherwise
                    assert(false);
            end
        end
    end
    
    %% HIDDEN METHODS (Usr/Cfg/FastCfg API)
    
    methods (Access=private)
        function fname = zprvUserCfgFileHelper(obj,fname,fileFcn,verifyFcn) %#ok<MANU>
            % Get/preprocess/verify a config filename. Set 'lastConfigFilePath'
            % classdatavar, obj.cfgFilename.
            
            if isempty(fname)
                [f,p] = fileFcn();
                if isnumeric(f)
                    fname = [];
                    return;
                end
                fname = fullfile(p,f);
            else
                [p,f,e] = fileparts(fname);
                if isempty(p)
                    p = cd;
                end
                if isempty(e)
                    e = '.cfg';
                end
                f = [f e];
                fname = fullfile(p,f);
            end
            verifyFcn(p,f,fname);
        end
        
       
    end
    
    %% INIT METHODS
    methods
        
    end
    
    %% PROP ACCESS METHODS
    methods
        
        %% Timer functions
        function zprvUpdateSecondsCounter(obj)
            % Simple countup/countdown timer functionality.
            switch obj.acqState
                case 'focus'
                    obj.secondsCounter = obj.secondsCounter + 1;
                case 'grab'
                    obj.secondsCounter = obj.secondsCounter + 1;
                case 'loop_wait'
                    switch obj.secondsCounterMode
                        case 'up'
                            obj.secondsCounter = obj.secondsCounter + 1;
                        case 'down'
                            obj.secondsCounter = obj.secondsCounter - 1;
                    end
                case 'loop'
                    switch obj.secondsCounterMode
                        case 'up'
                            obj.secondsCounter = obj.secondsCounter + 1;
                        case 'down'
                            obj.secondsCounter = obj.secondsCounter - 1;
                    end
                otherwise
            end
        end
        
        %% most.MachineDataFile related functions.
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
        
        %% SI5 PROPERTY ACCESS METHODS
        
        function zprvUpdateMergeWindowIfNecessary(obj,tileIdx)
            %             if obj.channelsMergeEnable && strcmp(obj.initState,'none') && ...
            %                     (~obj.channelsMergeFocusOnly || ~any(strcmp(obj.acqState,{'grab' 'loop'})))
            if obj.channelsMergeEnable && (~obj.channelsMergeFocusOnly || ~any(strcmp(obj.acqState,{'grab' 'loop'})))
                if nargin < 2
                    tileIdx = 1:length(obj.displayFrameBatchSelection);
                end
                
                chansToDisp = obj.channelsDisplay;
                mergeColors = obj.channelsMergeColor;
                sclpf = obj.linesPerFrame;
                sppl = obj.pixelsPerLine;
                
                for tIdx = tileIdx(:)'
                    if numel(obj.hMergeImages) < tIdx || ~ishandle(obj.hMergeImages(tIdx))
                        break;
                    end
                    
                    mergeData = zeros(sclpf,sppl,3,'uint8');
                    for chanIdx = chansToDisp(:)'
                        % for now, get chanData from hImages
                        chanData = get(obj.hImages{chanIdx}(tIdx),'CData');
                        chanProp = sprintf('chan%dLUT',chanIdx);
                        mergeData = obj.zprvAddChanDataToMergeData(mergeData,chanData,mergeColors{chanIdx},obj.(chanProp));
                    end
                    
                    set(obj.hMergeImages(tIdx),'CData',mergeData);
                end
            end
        end
        
        function data = zprvChannelDataCurrentDisplay(obj,chanIdx)
            % Return the data matrix for the currently-displayed data for the
            % specified channel. (The currently-displayed data is affected by
            % zooming, etc.)
            if ismember(chanIdx,obj.hMergeFigs)
                hIm = obj.hMergeImages;
                ax = obj.hMergeAxes;
            else
                hIm = obj.hImages{chanIdx};
                ax = obj.hAxes{chanIdx};
            end
            
            assert(isscalar(ax),'At this time, cannot extract data (for image statistics, etc) from multi-image display figures');
            
            xbounds = get(hIm,'XData');
            ybounds = get(hIm,'YData');
            ximagebounds = round(get(ax,'XLim'));
            yimagebounds = round(get(ax,'YLim'));
            xidxs = intersect(xbounds(1):xbounds(2),ximagebounds(1):ximagebounds(2));
            yidxs = intersect(ybounds(1):ybounds(2),yimagebounds(1):yimagebounds(2));
            
            data = get(hIm,'CData');
            data = data(yidxs,xidxs);
        end
        
        function zprvResetDisplayFigs(obj,chansToReset,resetMergeTF,channelsLUTVal)
            numTiles = length(obj.displayFrameBatchSelection); %Number of tiles to be displayed
            if numTiles > 1
                %Determine optimal tiling
                if numTiles == 2
                    tiling = [2 1];
                elseif numTiles <= 4
                    tiling = [2 2];
                elseif numTiles < 6
                    tiling = [3 2];
                else
                    tilingFactor = 3;
                    
                    while tilingFactor^2 < numTiles
                        tilingFactor = tilingFactor + 1;
                    end
                    
                    tiling = [tilingFactor tilingFactor];
                end
                tileSpans = 1./tiling;
            else
                % these will be unused
                tiling = [];
                tileSpans = [];
            end
            
            startImageData = zeros(obj.linesPerFrame,obj.pixelsPerLine,obj.channelsDataType);
            for i=1:length(chansToReset)
                chanNum = chansToReset(i);
                [obj.hAxes{chanNum} obj.hImages{chanNum} obj.hText{chanNum}] = ...
                    zprvPrepareDisplayAxesImages(obj,obj.hFigs(chanNum),numTiles,tiling,tileSpans,startImageData);
            end
            
            if resetMergeTF
                [obj.hMergeAxes obj.hMergeImages] = ...
                    zprvPrepareDisplayAxesImages(obj,obj.hMergeFigs,numTiles,tiling,tileSpans,startImageData);
                initialMergeData = zeros(obj.linesPerFrame,obj.pixelsPerLine,3,'uint8');
                set(obj.hMergeImages,'CData',initialMergeData);
            end
            
            %Update CLim values for each subplot
            if nargin < 4
                obj.chan1LUT = obj.chan1LUT;
                obj.chan2LUT = obj.chan2LUT;
                obj.chan3LUT = obj.chan3LUT;
                obj.chan4LUT = obj.chan4LUT;
            else
                channelsLUTValLookup = channelsLUTVal';
                obj.chan1LUT = channelsLUTValLookup(1:2);
                obj.chan2LUT = channelsLUTValLookup(3:4);
                obj.chan3LUT = channelsLUTValLookup(5:6);
                obj.chan4LUT = channelsLUTValLookup(7:8);
            end
        end
        
        function [hAx hIm hText] = zprvPrepareDisplayAxesImages(obj,hFig,numTiles,tiling,tileSpans,startImageData)
            %delete(findobj(hFig,'Type','Axes'));
            %delete(findall(hFig,'Type','Line'));
            clf(hFig); % Fix for Issue #75
            
            figure(hFig);
            set(hFig,'HandleVisibility','callback');

            hAx = zeros(numTiles,1);
            hIm = zeros(numTiles,1);
            hText = zeros(numTiles,1);
            if numTiles > 1
                %Draw annotation lines
                for i=1:(tiling(1)-1) %horizontal lines, separating rows
                    annotation('line',[0 1],[i*tileSpans(1) i*tileSpans(1)],'Color',[0.5 0.5 0.5]);
                end
                for i=1:(tiling(2)-1) %vertical lines, separating columns
                    annotation('line',[i*tileSpans(2) i*tileSpans(2)],[0 1],'Color',[0.5 0.5 0.5]);
                end
                
                %Create subplots (do in separate loop to avoid auto-deletion due to tiny overlaps)
                for tileIdx=1:numTiles
                    hAx(tileIdx) = subplot(tiling(1),tiling(2),tileIdx);
                end
                
                %Configure subplots
                for tileIdx=1:numTiles
                    rowIdx = floor((tileIdx-1)/tiling(2)) + 1; %Count from top
                    colIdx = mod(tileIdx-1,tiling(2)) + 1;  %Count from left
                    set(hAx(tileIdx),'Position',[(colIdx-1)*tileSpans(2) (tiling(1)-rowIdx)*tileSpans(1) tileSpans(2) tileSpans(1)] + [1e-9 1e-9 -2e-9 -2e-9],...
                        'Visible','off','YDir','reverse','XTick',[],'YTick',[],...
                        'YTickLabelMode','manual','XTickLabelMode','manual',...
                        'XTickLabel',[],'YTickLabel',[]);
                    
                    hIm(tileIdx) = image('Parent',hAx(tileIdx),'CData',startImageData,'CDataMapping','Scaled');
                    if obj.debugFrameNumbers
                        hText(tileIdx) = text(1,1,'...','Parent',hAx(tileIdx),'FontWeight','bold','Color','Red','FontSize',20,'HorizontalAlignment','Left','VerticalAlignment','Top');
                    end
                    obj.zprvUpdateChannelDisplayRatioAndLims(hAx(tileIdx)); %Update aspect ratio and limits
                end
            else
                hAx = axes('Parent',hFig,'Position',[0 0 1 1], ...
                    'YDir','reverse', 'DataAspectRatio',[obj.pixelsPerLine obj.linesPerFrame 1],...
                    'XTick',[],'YTick',[],...
                    'YTickLabelMode','manual','XTickLabelMode','manual','XTickLabel',[],'YTickLabel',[]);
                hIm = image('Parent',hAx,'CData',startImageData,'CDataMapping','Scaled');
                if obj.debugFrameNumbers
                    hText = text(1,1,'...','Parent',hAx,'FontWeight','bold','Color','Red','FontSize',20,'HorizontalAlignment','Left','VerticalAlignment','Top');
                end
                obj.zprvUpdateChannelDisplayRatioAndLims(hAx); %Update aspect ratio and limits
            end
        end
        
        function zprvUpdateChannelDisplayRatioAndLims(obj,hAx)
            if nargin < 2 || isempty(hAx)
                hAx = [obj.hAxes(:);{obj.hMergeAxes}];
            elseif ~iscell(hAx)
                hAx = {hAx};
            end
            
            if obj.mroiEnabled
                yRatio = 1;
                
                tileCols = obj.mroiComputedParams.dispTiling(2);
                
                imCols = tileCols * obj.mroiPixelsPerLine;
                imRows = sum([obj.mroiComputedParams.dispTilingLinesPerRow]);
                
            else
                imCols = obj.pixelsPerLine;
                imRows = obj.linesPerFrame;
                if obj.scanAngleMultiplierSlow == 0 %Line scan
                    yRatio = 1;
                else
                    yRatio = abs(obj.scanAngleMultiplierSlow);
                end
            end
            
            if obj.scanForceSquarePixel_
                cellfun(@(x)set(x,'PlotBoxAspectRatio',[1 yRatio 1],...
                    'DataAspectRatioMode','auto',...
                    'XLim',[-0.5 .5] + [1 imCols],...
                    'YLim',[-0.5 .5] + [1 imRows]),hAx);
            else
                cellfun(@(x)set(x,'PlotBoxAspectRatioMode','auto',...
                    'DataAspectRatioMode','auto',...
                    'XLim',[-0.5 .5] + [1 imCols],...
                    'YLim',[-0.5 .5] + [1 imRows]),hAx);
            end
            
            drawnow(); %Ensure all changes take effect before subsequent calls
        end
        
        function zprvInitializeMultiSliceMotors(obj)
            obj.hBeams.stackGrabActive = obj.stackNumSlices > 1;
            if obj.stackNumSlices > 1
                if obj.fastZEnable %A volume imaging acquisition
                    %******************************************************
                    %HANDLE FASTZ VOLUME CASE
                    %******************************************************
                    obj.hFastZ.zprvFastZUpdateAOData();
                    
                    %Prepare beam output buffer, if needed
                    if  (obj.hBeams.beamFlybackBlanking || obj.beamPzAdjust)
                        obj.hBeams.zprvBeamsWriteFastZData(); %Overwrites standard beam data written with zprvBeamsWriteFlybackDAta()
                        
                        if obj.fastZAllowLiveBeamAdjust && obj.hBeams.beamNumBeams > 0
                            obj.hBeams.set('writeRelativeTo','DAQmx_Val_FirstSample');
                        end
                    end
                    
                    if obj.stackReturnHome
                        if obj.hFastZ.fastZSecondMotor
                            obj.hFastZ.fastZHomePosition = obj.hFastZ.positionAbsolute(end); %Store original position
                        else
                            obj.hFastZ.fastZHomePosition = obj.hFastZ.positionAbsolute(1); %Store original position
                        end
                    end
                else
                    assert(obj.hMotors.motorHasMotor);
                    
                    obj.hAcq.loggingSlowStack = true;
                    
                    obj.hMotors.zprvSetHome();
                    obj.hBeams.zprvSetHome();
                    
                    %******************************************************
                    %MOTORS
                    %******************************************************
                    % Deal with starting zpos
                    preStartZIncrement = []; %#ok<NASGU> % This is the size of the motor move we will execute pre-stack. This is set in the next block.
                    if ~isnan(obj.stackZStartPos)
                        if obj.stackStartCentered
                            warnst = warning('off','backtrace');
                            warning('SI5:ignoringStackStartCentered',...
                                'Starting z-position for stack has been set. Stack will not be centered around the current zposition.');
                            warning(warnst);
                        end
                        
                        % Throw a warning if the current position does
                        % not match stackLastStartEndPositionSet or the
                        % calculated stack final position. When this
                        % condition holds, it is probable that the user
                        % has moved the motor position after setting up
                        % (and possibly running) a stack. In this
                        % situation the stackZStart/EndPos info may
                        % potentially be stale.
                        currStackZPosn = obj.hMotors.stackCurrentMotorZPos;
                        stackFinalZPos = obj.stackZStartPos + (obj.stackNumSlices-1)*obj.stackZStepSize; % in this codepath, the stack starting pos is obj.stackZStartPos
                        if ~isequal(currStackZPosn,obj.stackLastStartEndPositionSet) && ...
                                ~isequal(currStackZPosn,stackFinalZPos) % this condition is for when stackZStartPos is set last, and stackReturnHome is false.
                            warnst = warning('off','backtrace');
                            warning('SI5:stackWithPotentiallyStaleStartEndPos',...
                                'Motor has moved since last stack start/end position was set.');
                            warning(warnst);
                        end
                        
                        preStartZIncrement = obj.stackZStartPos-currStackZPosn;
                        posn = obj.hMotors.stackZMotor.positionRelative;
                        posn(3) = obj.stackZStartPos;
                        obj.hMotors.stackZMotor.moveCompleteRelative(posn);
                        obj.stackRefZPos = posn(3);
                    elseif obj.stackStartCentered
                        totalStackdz = (obj.stackNumSlices-1)*obj.stackZStepSize;
                        preStartZIncrement = -totalStackdz/2;
                        posn = obj.hMotors.stackZMotor.positionRelative;
                        posn(3) = posn(3) + preStartZIncrement;
                        obj.hMotors.stackZMotor.moveCompleteRelative(posn);
                        obj.stackRefZPos = posn(3);
                    else
                        % none; start stack at current zpos
                        preStartZIncrement = 0.0;
                        obj.stackRefZPos = obj.hMotors.stackZMotor.positionRelative(3);
                    end
                    obj.notify('motorPositionUpdate'); %Signal potential motor position update
                    
                    % set total stack Dz
                    totalStackDz = (obj.stackNumSlices-1)*obj.stackZStepSize;
                end
            end
        end
        
        
        function zprvInitializeMultiSliceMotorsAndBeams(obj)
            obj.hBeams.stackGrabActive = obj.stackNumSlices > 1;
            if obj.stackNumSlices > 1
                if obj.fastZEnable %A volume imaging acquisition
                    %******************************************************
                    %HANDLE FASTZ VOLUME CASE
                    %******************************************************
                    obj.hFastZ.zprvFastZUpdateAOData();
                    
                    %Prepare beam output buffer, if needed
                    if  (obj.hBeams.beamFlybackBlanking || obj.beamPzAdjust)
                        obj.hBeams.zprvBeamsWriteFastZData(); %Overwrites standard beam data written with zprvBeamsWriteFlybackDAta()
                        
                        if obj.fastZAllowLiveBeamAdjust && obj.hBeams.beamNumBeams > 0
                            obj.hBeams.set('writeRelativeTo','DAQmx_Val_FirstSample');
                        end
                    end
                    
                    if obj.stackReturnHome
                        if obj.hFastZ.fastZSecondMotor
                            obj.hFastZ.fastZHomePosition = obj.hFastZ.positionAbsolute(end); %Store original position
                        else
                            obj.hFastZ.fastZHomePosition = obj.hFastZ.positionAbsolute(1); %Store original position
                        end
                    end
                else
                    %******************************************************
                    %HANDLE SLOW STACK VOLUME CASE
                    %******************************************************
                    %Taking a motor-driven image stack
                    %Before first slice in stack
                    assert(obj.hMotors.motorHasMotor);
                    
                    %Disable logging rollover on each subsequent acq.
                    %This must be set to true for all acq's except for the
                    %first. It then must be disabled when the slow stack is
                    %complete.
                    %
                    %When logging Frames Per File Lock is set to true, then
                    %disable slow stack mode in logger. Otherwise, use slow
                    %stack mode by default. (This is SI4.2 functionality.)
                    obj.hAcq.loggingSlowStack = true;
                    
                    %NOTE: THE FOLLOWING IS FOR SLOW STACK ONLY
                    %Tell the framelogger (through the resonant acq object)
                    %how many slices aka acq triggers to capture before
                    %rolling over a new file.
                    obj.hAcq.loggingNumSlowStackSlices = obj.stackNumSlices;
                    
                    %Note: obj.hAcq.framesPerAcquisition tells the C
                    %side how many frames are in a slice.
                    
                    % Deal with return-home
                    obj.hMotors.zprvSetHome();
                    obj.hBeams.zprvSetHome();
                    
                    %******************************************************
                    %MOTORS
                    %******************************************************
                    % Deal with starting zpos
                    preStartZIncrement = []; %#ok<NASGU> % This is the size of the motor move we will execute pre-stack. This is set in the next block.
                    if ~isnan(obj.stackZStartPos)
                        if obj.stackStartCentered
                            warnst = warning('off','backtrace');
                            warning('SI5:ignoringStackStartCentered',...
                                'Starting z-position for stack has been set. Stack will not be centered around the current zposition.');
                            warning(warnst);
                        end
                        
                        % Throw a warning if the current position does
                        % not match stackLastStartEndPositionSet or the
                        % calculated stack final position. When this
                        % condition holds, it is probable that the user
                        % has moved the motor position after setting up
                        % (and possibly running) a stack. In this
                        % situation the stackZStart/EndPos info may
                        % potentially be stale.
                        currStackZPosn = obj.hMotors.stackCurrentMotorZPos;
                        stackFinalZPos = obj.stackZStartPos + (obj.stackNumSlices-1)*obj.stackZStepSize; % in this codepath, the stack starting pos is obj.stackZStartPos
                        if ~isequal(currStackZPosn,obj.stackLastStartEndPositionSet) && ...
                                ~isequal(currStackZPosn,stackFinalZPos) % this condition is for when stackZStartPos is set last, and stackReturnHome is false.
                            warnst = warning('off','backtrace');
                            warning('SI5:stackWithPotentiallyStaleStartEndPos',...
                                'Motor has moved since last stack start/end position was set.');
                            warning(warnst);
                        end
                        
                        preStartZIncrement = obj.stackZStartPos-currStackZPosn;
                        posn = obj.hMotors.stackZMotor.positionRelative;
                        posn(3) = obj.stackZStartPos;
                        obj.hMotors.stackZMotor.moveCompleteRelative(posn);
                        obj.stackRefZPos = posn(3);
                    elseif obj.stackStartCentered
                        totalStackdz = (obj.stackNumSlices-1)*obj.stackZStepSize;
                        preStartZIncrement = -totalStackdz/2;
                        posn = obj.hMotors.stackZMotor.positionRelative;
                        posn(3) = posn(3) + preStartZIncrement;
                        obj.hMotors.stackZMotor.moveCompleteRelative(posn);
                        obj.stackRefZPos = posn(3);
                    else
                        % none; start stack at current zpos
                        preStartZIncrement = 0.0;
                        obj.stackRefZPos = obj.hMotors.stackZMotor.positionRelative(3);
                    end
                    obj.notify('motorPositionUpdate'); %Signal potential motor position update
                    
                    % set total stack Dz
                    totalStackDz = (obj.stackNumSlices-1)*obj.stackZStepSize;
                    
                    %******************************************************
                    %BEAMS
                    %******************************************************
                    %Only handle beams if we have any in the rig.
                    if(obj.beamNumBeams > 0)
                        % deal with starting power
                        if obj.stackUseStartPower && obj.hBeams.stackStartPowerDefined
                            % use stack starting power; ignore any
                            % correction due to preStartZIncrement and Lz
                            obj.hBeams.zprvSetInternal('beamPowers',obj.stackStartPower);
                        else
                            % correct starting power using acquisition Lz (could be overridden, etc)
                            obj.hBeams.zprvBeamsDepthPowerCorrection(preStartZIncrement,obj.hBeams.acqBeamLengthConstants);
                        end
                        
                        % throw a warning if the final power will exceed 100%
                        beamPwrs = obj.hBeams.beamPowers; % beam powers have been initialized to stack-start values
                        finalPwrs = beamPwrs.*exp(totalStackDz./obj.hBeams.acqBeamLengthConstants'); %This line forces acqBeamLengthConstants to be computed, if not done so already
                        if any(finalPwrs(:)>100)
                            warnst = warning('off','backtrace');
                            warning('SI5:beamPowerWillSaturate',...
                                'Beam power correction will cause one or more beams to exceed 100%% power at or before stack end. Beam power will saturate at 100%%.');
                            warning(warnst);
                        end
                    end
                end
            end
        end
        
        function zprvResetHome(obj)
            %Reset home motor/fastZ/beam positions/powers
            obj.hMotors.zprvResetHome();
            obj.hFastZ.zprvResetHome();
            obj.hBeams.zprvResetHome();
        end
        
        function zprvGoHome(obj)
            %Go to home motor/fastZ/beam positions/powers, as applicable
            if obj.stackReturnHome
                obj.hMotors.zprvGoHome();
                obj.hFastZ.zprvGoHome();
                obj.hBeams.zprvGoHome();
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
        
        function zprvResetAcqCounters(obj,resetLoop)
            %resetLoop: <Default=true> If true, reset Loop and total acqFramesDone counters
            
            %If in loop acquisition, do not reset the loopAcqCounter.
            if ~strcmpi(obj.acqState,'loop') && ~strcmpi(obj.acqState,'loop_wait')
                obj.loopAcqCounter = 0;
            end
            
            obj.acqFramesDone = 0;
            obj.stackSlicesDone = 0;
            obj.scanFramesStarted = 0;
            obj.fastZVolumesDone = 0;
            
            %Reset Frame Counter.
            obj.frameCounter = 0;
            obj.frameCounterDisplay = 0;
            
            if nargin < 2 || resetLoop
                obj.acqFramesDoneTotal = 0;
            end
        end
        
        function zprvResetBuffersIfFocusing(obj)
            %Handle case where buffer reset should occur only during an ongoing Focus
            if strcmpi(obj.acqState,'focus')
                obj.acqFramesDone = 0;
                %obj.acqFramesDoneTotal = 0;
                obj.zprvResetBuffers();
            else
                return;
            end
        end
        
        function zprvResetBuffers(obj)
            obj.acqFrameBuffer = cell(obj.acqFrameBufferLength,1);
            obj.acqFrameNumberBuffer = cell(obj.acqFrameBufferLength,1);
            
            % Pre-fill acqFrameBuffer with empty cell arrays.
            for j=1:obj.acqFrameBufferLength
                obj.acqFrameBuffer{j} = cell(obj.MAX_NUM_CHANNELS,1);
                for i=1:obj.MAX_NUM_CHANNELS
                    obj.acqFrameBuffer{j}{i} = zeros(obj.linesPerFrame,obj.pixelsPerLine,'double');
                end
                obj.acqFrameNumberBuffer{j} = 0;
            end
            
            %obj.displayRollingBuffer = cell(obj.acqFrameBufferLength,1);
            %Not sure why the original code had the number of cells in the
            %displayRollingBuffer equal to the acqFrameBufferLength.
            obj.displayRollingBuffer = cell(numel(obj.displayFrameBatchSelection),1);
            numTiles = length(obj.displayFrameBatchSelection);
            
            if obj.displayRollingAverageFactor > 1
                for j=1:numTiles
                    for i=1:obj.MAX_NUM_CHANNELS
                        if ismember(i,obj.channelsDisplay)
                            obj.displayRollingBuffer{j}{i} = zeros(obj.linesPerFrame,obj.pixelsPerLine,'double');
                        end
                    end
                    obj.displayRollingBuffer{j} = obj.displayRollingBuffer{j}';
                end
            else
                obj.displayRollingBuffer = { };
            end
        end
        
        function zprvMotorErrorCbk(obj,src,evt) %#ok<INUSD>
            if obj.isLive()
                fprintf(2,'Motor error occurred. Aborting acquisition.\n');
                obj.abort();
            end
        end
        
        %         function zprvLoadPlugins(obj)
        %             p = fileparts(mfilename('fullpath'));
        %             pluginList = ls([p '\+plugins\@*']);
        %             if isempty(pluginList)
        %                 return
        %             end
        %
        %             %Remove the @ from the plugin names
        %             pluginList = pluginList(:,2:end);
        %
        %             for i = 1:size(pluginList,1)
        %                 pluginName = pluginList(i,:);
        %                 startSpaces = regexp(pluginName,'[ ]+$'); % find spaces at end of pluginName
        %                 if ~isempty(startSpaces)
        %                     pluginName = pluginName(1:startSpaces-1);
        %                 end
        %
        %                 hPlugin = scanimage.plugins.(pluginName)(obj);
        %                 if isvalid(hPlugin)
        %                     obj.hPlugins{end+1} = hPlugin;
        %                 else
        %                     s = warning('backtrace','off');
        %                     warning('SI5: Failed to load plugin ''%s''',pluginName);
        %                     warning(s);
        %                 end
        %             end
        %         end
        
        function tf = zprvValidateLoggingFile(obj)
            fileName = obj.hAcq.loggingFullFileName;
            
            tf = false;
            
            %Check that file save path is specified -- provide opportunity if not
            if isempty(obj.loggingFilePath)
                button = questdlg('A Save path has not been selected.','Do you wish to:','Select New Path','Use Current','Cancel','Select New Path');
                if strcmp(button,'Select New Path')
                    obj.setSavePath();
                    if isempty(obj.loggingFilePath) %User may cancel
                        return;
                    end
                elseif strcmp(button,'Use Current')
                    obj.loggingFilePath = pwd();
                elseif strcmp(button,'Cancel')
                    return;
                end
            end
            
            %Check that filename stem is specified -- provide opportunity if not
            if isempty(obj.loggingFileStem)
                answer  = inputdlg('Select base name','Choose Base Name for Acquisition',1,{''});
                if ~isempty(answer)
                    try
                        obj.loggingFileStem = answer{1};
                    catch %#ok<CTCH>
                        errordlg('Invalid filename stem specified. Cancelling.');
                        return;
                    end
                else
                    return;
                end
            end
            
            %Check that file doesn't already exist -- provide opportunity to fix
            if ~isinf(obj.loggingFramesPerFile)
                fileExists = exist(sprintf('%s_%0.3d_%0.3d.tif',obj.hAcq.loggingFullFileName,obj.loggingFileCounter,obj.loggingFileSubCounter));
            else
                fileExists = exist(sprintf('%s_%0.3d.tif',obj.hAcq.loggingFullFileName,obj.loggingFileCounter));
            end
            
            if fileExists
                button = questdlg(sprintf('File Already Exists - ''%s''.  Do you wish to:', fileName), ...
                    'Overwrite warning!',...
                    'Update Filename','Overwrite', 'Cancel', 'Update Filename');
                
                drawnow;  %Mysteriously required to avoid subsequent motor error. Neither drawnow expose/update works -- need full drawnow.
                
                switch button
                    case 'Overwrite'
                        %Clear out old data in advance -- this is required if to save during acquisition
                        %recycleFile(fileName); - Not necessary.
                        tf = true;
                    case 'Update Filename'
                        
                        answer = inputdlg({'Basename:' 'Acquisition Number:'}, 'Update Basename and/or Acq Number', 1, {obj.loggingFileStem num2str(obj.loggingFileCounter+1)});
                        drawnow; %Mysteriously required to avoid subsequent motor error. Neither drawnow expose/update works -- need full drawnow.
                        
                        try
                            obj.loggingFileStem = answer{1};
                            obj.loggingFileCounter = round(str2double(answer{2}));
                        catch %#ok<CTCH>
                            errordlg('Invalid file stem or counter specified. Cancelling acquisition');
                            return;
                        end
                        
                        if exist(obj.hAcq.loggingFullFileName,'file')
                            errordlg('Newly specified file stem/number also already exists! Cancelling acquisition.');
                            tf = false;
                            return;
                        end
                        
                        tf = true;
                        
                    case 'Cancel'
                        %do nothing
                end
            else
                tf = true;
            end
        end
        
        function setSavePath(obj,pathDir)
            %Set loggingFilePath property to specified/selected folder path for
            %image file logging during Grab/Loop acquisitions.
            
            if nargin > 1
                assert(exist(pathDir,'dir'),'Specified directory does not exist');
                p = pathDir;
            else
                startPath = obj.loggingFilePath;
                
                if isempty(startPath)
                    startPath = most.idioms.startPath();
                end
                
                p = uigetdir(startPath, 'Select Save Path');
            end
            
            if p
                obj.loggingFilePath=p;
                disp(['*** SAVE PATH = ' p ' ***']);
            end
        end
        
        function tf = isLive(obj)
            tf = ismember(obj.acqState,{'focus' 'grab' 'loop'});
        end
        
        %% SI5 FASTZ METHODS
        function continueTF = zprvEnsureScannerPeriodMeasured(obj)
            %Ensure LSM line period has been measured at current scan settings, initiating measurement if neeed
            %Return false if LSM line period was not previously measured (even if it is measured by this function)
            
            continueTF = ~isnan(obj.scanFramePeriod);
            
            if ~continueTF
                resp = questdlg('Scan Line Period has not been measured for installed scanner parameters, which is required prior to acquisition. Do this now?','Scan Line Period not measured', 'OK','Cancel','OK');
                switch resp
                    case 'OK'
                        obj.scannerPeriodMeasure();
                    case 'Cancel'
                        %Do nothing
                end
            end
        end
        
        %% Timer properties
        function val = get.secondsCounterMode(obj)
            switch obj.acqState
                case {'focus' 'grab'}
                    val = 'up';
                case {'loop' 'loop_wait'}
                    if isinf(obj.loopAcqInterval) || obj.triggerTypeExternal
                        val = 'up';
                    else
                        val = 'down';
                    end
                otherwise
                    val = '';
            end
        end
        
        %% Acquisition properties
        function set.frameCounterDisplay(obj,val)
            if val > 0
                if ~isequal(obj.acqMode,'focus')
                    obj.frameCounterDisplay = val;
                end
            else
                obj.frameCounterDisplay = 0;
            end
        end
        
        function set.acqState(obj,val)
            assert(ismember(val,{'idle' 'focus' 'grab' 'loop' 'loop_wait' 'point'}));
            obj.acqState = val;
            
            %Side-effects
            %TODO: Is this really necessary?
            obj.hBeams.acqState = val;
            obj.hMotors.acqState = val;
            obj.hFastZ.acqState = val;
        end
        
        function set.bidirectionalAcq(obj,val)
            obj.zprvAssertFocusOrIdle('bidirectionalAcq');
            
            val = obj.validatePropArg('bidirectionalAcq',val);
            obj.bidirectionalAcq = (val == 1);
            
            %Side-effects
            obj.hFastZ.bidirectionalAcq = val;
            
            if ~obj.cfgLoading
                obj.zprpSetAcqAndScanParameters;
            end
        end
        
        function set.pixelsPerLine(obj,val)
            obj.zprvAssertFocusOrIdle('pixelsPerLine');
            
            val = obj.validatePropArg('pixelsPerLine',val);
            
            % in acquisition mode focus a change of pixelsPerLine should
            % stop the acquisition, change the parameter and restart
            rearmFocus = false;
            if strcmp(obj.acqState,'focus')
                obj.abort();
                rearmFocus = true;
            end
            
            %Side-effects
            if obj.scanSetPixelationPropFlag
                obj.pixelsPerLine = val;
                obj.hAcq.pixelsPerLine = val;
            else
                obj.zprpSetPixelationProp('pixelsPerLine',val);
            end
            
            if rearmFocus
                obj.startFocus();
            end
        end
        
        function set.fillFraction(obj,val)
            obj.zprvAssertFocusOrIdle('fillFraction');
            val = obj.validatePropArg('fillFraction',val);
            obj.fillFraction = val;
            
            %Side-effects
            obj.hAcq.fillFraction = val;
            obj.hScan.galvoFillFraction = val;
            obj.hBeams.scanLinePeriod = obj.hAcq.scanLineDuration;
            obj.hBeams.scanFillFraction = val;
            
            if ~obj.cfgLoading
                obj.zprpSetAcqAndScanParameters;
            end
        end
        
        function value = get.fillFraction(obj)
            value = obj.fillFraction;
        end
        
        function value = get.fillFractionTime(obj)
            value = 1 - ( 2/pi *acos(obj.fillFraction) );
        end
        
        function set.scanForceSquarePixel(obj,val)
            obj.validatePropArg('scanForceSquarePixel',val);
            obj.scanForceSquarePixel = val;
            
            %Side-effects
            if obj.scanForceSquarePixel_
                obj.scanAngleMultiplierSlow = sign(obj.scanAngleMultiplierSlow) * (obj.linesPerFrame/obj.pixelsPerLine);
            end
        end
        
        function val = get.scanForceSquarePixel_(obj)
            val = obj.scanForceSquarePixel;% && abs(obj.scanAngleMultiplierSlow) > 0;
        end
        
        function val = get.scanForceSquarePixelation_(obj)
            val = obj.scanForceSquarePixelation && abs(obj.scanAngleMultiplierSlow) > 0;
        end
        
        function set.scanForceSquarePixel_(obj,val)
            obj.mdlDummySetProp(val,'scanForceSquarePixel_');
        end
        
        function set.scanForceSquarePixelation(obj,val)
            obj.validatePropArg('scanForceSquarePixelation',val);
            obj.scanForceSquarePixelation = val;
            
            %Side-effects
            if obj.scanForceSquarePixelation_ && obj.linesPerFrame ~= obj.pixelsPerLine
                obj.linesPerFrame = obj.pixelsPerLine;
            end
        end
        
        function set.scanForceSquarePixelation_(obj,val)
            obj.mdlDummySetProp(val,'scanForceSquarePixelation_');
        end
        
        function val = get.scanPixelTimeMean(obj)
            val = obj.scanPixelTimeStats.meanPixelTime;
        end
        
        function val = get.scanPixelTimeMaxMinRatio(obj)
            val = obj.scanPixelTimeStats.pixelTimeRatio;
        end
        
        function val = get.scanPixelTimeStats(obj)
            %Compute the mean pixel time.
            meanPixelTime = (sum(obj.hAcq.mask(1:obj.pixelsPerLine)) / obj.hAcq.sampleRate) / obj.pixelsPerLine;
            %Pixel time max / min ratio
            maxPixelSamples = max(obj.hAcq.mask(1:obj.pixelsPerLine));
            minPixelSamples = min(obj.hAcq.mask(1:obj.pixelsPerLine));
            pixelTimeRatio = maxPixelSamples / minPixelSamples;
            
            %Form struct for return
            val = struct('pixelTimeRatio',pixelTimeRatio,'meanPixelTime',meanPixelTime);
        end
        
        function set.scanPixelTimeMean(obj,val)
            obj.mdlDummySetProp(val,'scanPixelTimeMean');
        end
        
        function set.scanPixelTimeMaxMinRatio(obj,val)
            obj.mdlDummySetProp(val,'scanPixelTimeMaxMinRatio');
        end
        
        function set.scanPixelTimeStats(obj,val)
            obj.mdlDummySetProp(val,'scanPixelTimeStats');
        end
        
        function set.scanShiftSlow(obj,val)
            obj.scanShiftSlow = val;
            
            %Side effects
            obj.hScan.galvoOffsetDeg = val; %val in degrees
        end
        
        function val = get.scanShiftSlow(obj)
            val = obj.scanShiftSlow;
        end
        
        function set.scanAngleMultiplierSlow(obj,val)
            obj.zprvAssertFocusOrIdle('scanAngleMultiplierSlow');
            val = obj.validatePropArg('scanAngleMultiplierSlow',val);
            
            if obj.scanForceSquarePixel_ && val ~= 0  %Allow change of slow scan angle multiplier when linescanning.
                assert(abs(val) == (obj.linesPerFrame/obj.pixelsPerLine),'With Square Pixel constraint enabled, only sign changes of scanAngleMultiplierSlow are allowed');
            end
            
            obj.scanAngleMultiplierSlow = val;
            
            %Side effects
            obj.hScan.galvoScanAngleMultiplier = abs(obj.scanAngleMultiplierSlow);
            obj.hScan.galvoInvertScanDirection = obj.scanAngleMultiplierSlow < 0;

            %Force change in channel display aspect ratio.
            obj.zprvResetBuffersIfFocusing(); %Clears acqFrameBuffer & displayRollingBuffer
            %obj.zprvResetDisplayFigs(obj.channelsDisplay,false);
            %necessary since scan angle multiplier slow does not alter
            %actual display properties.
        end
        
        function set.fillFractionTime(obj,val)
            obj.zprvAssertIdle('fillFraction');
            val = obj.validatePropArg('fillFractionTime',val);
            obj.fillFraction = cos((1-val)*pi/2);
        end
        
        function val = get.linePeriod_(obj)
            val = 1e6/obj.resonantScannerFreq; %line Period in us
        end
        
        function set.frameAcqFcnDecimationFactor(obj,val)
            val = obj.validatePropArg('frameAcqFcnDecimationFactor',val);
            fafDecFactor = val;
            
            %Side-effects: update attendant LSM property; constrain loggingFramesPerFile and other properties
            if ~isempty(val)
                %TODO: Send frame event decimation factor to matlab
                %callback processing.
                disp('TODO: set.frameAcqFcnDecimationFactor(obj,val)');
                cellfun(@(x)obj.zprpApplyFAFDecFactorConstraint(x,fafDecFactor),{'loggingFramesPerFile' 'displayFrameBatchFactor' 'displayFrameBatchSelection' 'acqNumFrames' 'stackNumSlices'},'UniformOutput',false);
            end
        end
        
        function val = get.frameAcqFcnDecimationFactor(obj)
            %TODO: Get frame event decimation factor from matlab
            %callback.
            %disp('TODO: get.frameAcqFcnDecimationFactor(obj)');
            val=1;
        end
        
        function set.linePeriod_(obj,val)
            obj.mdlDummySetProp(val,'linePeriod_');
        end
        
        function val = get.scanFrameRate_(obj)
            val = obj.resonantScannerFreq*(2^obj.bidirectionalAcq)/(obj.linesPerFrame+obj.flybackLinesPerFrame);
        end
        
        function set.resonantScannerFreq(obj,val)
            obj.resonantScannerFreq = val;
            
            %side effects
            obj.hFastZ.resonantScannerFreq = val;
        end
        
        function set.scanFrameRate_(obj,val)
            %Side Effects
            obj.hBeams.zprvBeamsUpdateFlybackBuffer();
            obj.hFastZ.zprvFastZUpdateAODataNormalized();
            
            obj.mdlDummySetProp(val,'scanFrameRate_');
        end
        
        function val = get.scanFramePeriod(obj)
            val = 1 / obj.scanFrameRate_;
        end
        
        function set.scanFramePeriod(obj, val)
            obj.mdlDummySetProp(val,'scanFramePeriod');
        end
        
        function set.periodClockPhase(obj,val)
            if val < obj.scanPhaseRange(1)
                val =  obj.scanPhaseRange(1);
            elseif val > obj.scanPhaseRange(2)
                val = obj.scanPhaseRange(2);
            end
            
            val = obj.validatePropArg('periodClockPhase',val);
            obj.periodClockPhase = val;
            
            %Side effects
            
            if ~obj.zoomChanged && obj.scanPhaseChanged
                obj.scanPhaseMap(obj.zoomFactor) = obj.periodClockPhase;
                obj.scanPhaseChanged = false;
            elseif obj.zoomChanged
                obj.zoomChanged = false;
            end
            
            obj.hAcq.periodClockPhase = obj.periodClockPhase;
            obj.scanPhaseChanged = false;
        end
        
        function set.multiChannel(obj,val)
            assert(isequal(obj.acqState,'idle'),'Cannot set single/multichannel mode during active acquisition');
            val = obj.validatePropArg('multiChannel',val);
            obj.multiChannel = val;
            
            %Side effects
            obj.hAcq.multiChannel = val;
            
            if val %Multi-channel
                %                 if isempty(obj.channelsDisplay)
                %                     obj.channelsDisplay = 1;
                %                 end
                
                %TODO: Make ResonantAcq (hAcq) object respect the
                %channelsDisplay proprety (for logging etc)
            else
                if ~isempty(obj.channelsDisplay)
                    %obj.channelsDisplay = obj.channelsDisplay(1);
                    obj.hAcq.singleChannelNumber = obj.channelsDisplay;
                end
            end
        end
        
        %% Channel properties
        function val = zprpMultichannelStatus(obj)
            if obj.loggingEnable
                %If logging is enabled, then use both save and display checkboxes.
                val = numel(obj.channelsSave) > 1 || ...
                    numel(obj.channelsDisplay ) > 1 || ...
                    isempty(intersect(obj.channelsSave,obj.channelsDisplay)) && ~isempty(obj.channelsDisplay) && ~isempty(obj.channelsSave);
            else
                %If logging is disabled, then only use display checkboxes.
                val = numel(obj.channelsDisplay) > 1;
            end
        end
        
        function set.channelsDisplay(obj,val)
            obj.zprvAssertIdle('channelsDisplay');
            val = obj.validatePropArg('channelsDisplay',val);
            val = obj.zprpValidateChannelsArray(val,'channelsDisplay');
            
            channelsDisplay_old = obj.channelsDisplay;
            obj.channelsDisplay = val;
            
            %Switch to single/multichannel appropriately.
            %obj.multiChannel = numel(val) > 1 || numel(obj.channelsSave) > 1 && obj.loggingEnable || (isempty(intersect(obj.channelsSave,val)) && ~isempty(val) && ~isempty(obj.channelsSave) && obj.loggingEnable);
            obj.multiChannel = obj.zprpMultichannelStatus();
            
            %Side effects
            %obj.zprpUpdateScanPhaseFine();
            %disp('TODO: set.channelsDisplay(obj,val) zprpUpdateScanPhaseFine??');
            for chan = 1:numel(obj.hFigs)
                hFig = obj.hFigs(chan);
                visible = ~isempty(find(obj.channelsDisplay==chan,1));
                activated = visible && isempty(find(channelsDisplay_old==chan,1));
                if activated
                    obj.zprvResetDisplayFigs(chan,false);
                end
                if visible
                    figVisible = get(hFig,'visible');
                    if ~strcmp(figVisible,'on');
                        % only set property when it is changed to reduce flickering of the figure window
                        set(hFig,'visible','on');
                    end
                end
            end
        end
        
        function set.channelsSave(obj,val)
            obj.zprvAssertIdle('channelsSave');
            val = obj.validatePropArg('channelsSave',val);
            val = obj.zprpValidateChannelsArray(val,'channelsSave');
            %val = intersect(val,obj.channelsDisplay);
            
            obj.channelsSave = val;
            obj.hAcq.loggingChannelsArray = val;
            %Switch to single/multichannel appropriately.
            %obj.multiChannel = ( obj.loggingEnable && numel(val) > 1 ) || numel(obj.channelsDisplay) > 1 || (isempty(intersect(obj.channelsDisplay,val)) && ~isempty(val) && ~isempty(obj.channelsDisplay) && obj.loggingEnable);
            obj.multiChannel = obj.zprpMultichannelStatus();
            
            %Side effects
            %obj.zprpUpdateScanPhaseFine();
            %disp('TODO: set.channelsSave(obj,val) zprpUpdateScanPhaseFine??');
        end
        
        function set.channelOffsets(obj,val)
            
            obj.channelOffsets = val; %internal - trust w/o validation
            
            %Side effects
            if obj.mdlInitialized
                obj.zprpUpdateAcqChannelOffsets();
            end
        end
        
        function set.channelsSubtractOffset(obj,val)
            val = obj.validatePropArg('channelsSubtractOffset',val);
            val = obj.zprpEnsureChannelPropSize(val);
            
            obj.channelsSubtractOffset = val;
            
            %Side effects
            obj.zprpUpdateAcqChannelOffsets();
        end
        
        function set.channelsInputRange(obj,val)
            %TODO: The 'digitizer' should know the number of channels it has
            %             assert(iscell(val) && isvector(val) && length(val)==obj.MAX_NUM_CHANNELS, 'Value must be a vector cell array of length %d',obj.MAX_NUM_CHANNELS);
            %             assert(all(cellfun(@(x)isempty(x) || ismember(x,obj.channelsInputRangeValues,'rows'),val)),'Each cell array element must be empty, or specify a valid channelInputRange value');
            
            obj.zprvAssertFocusOrIdle('channelsInputRange');
            val = obj.validatePropArg('channelsInputRange',val);
            val = obj.zprpEnsureChannelPropSize(val);
            
            obj.hAcq.channelsInputRanges = val;
            obj.channelsInputRange = val;
            
            %Side-effects
            if  any(~isnan(obj.channelOffsets))
                if obj.cfgLoading
                    % do nothing
                elseif strcmpi(obj.acqState,'idle')
                    obj.channelsReadOffsets(); %Offset values can change when input range is changed - so update the last-measured values
                    obj.channelsSubtractOffset = obj.channelsSubtractOffset;
                    %elseif any(obj.channelsSubtractOffset)
                elseif strcmpi(obj.acqState,'focus')
                    %Abort ongoing Focus, to get a new offset reading
                    obj.abort();
                    if ~obj.channelsAutoReadOffsets 
                        obj.channelsReadOffsets();
                        obj.channelsSubtractOffset = obj.channelsSubtractOffset;
                    end
                    obj.startFocus();
                else
                    disp('Cannot interrupt grab or loop to read channel offset. Switch to Focus mode or stop Grab/Loop.');
                end
            end
        end
        
        function set.channelsMergeColor(obj,val)
            %if ~isequal(val,obj.channelsMergeColor) % setabort %VI20111114: is this setabort construction needed anymore??
            val = obj.validatePropArg('channelsMergeColor',val); %allow during acq
            val = obj.zprpEnsureChannelPropSize(val);
            
            obj.channelsMergeColor = val;
            
            obj.zprvUpdateMergeWindowIfNecessary();
            %end
        end
        
        function set.channelsMergeEnable(obj,val)
            val = obj.validatePropArg('channelsMergeEnable',val); %allow during acq
            obj.channelsMergeEnable = val;
            if val
                obj.zprvResetDisplayFigs([],true); %Resets merge figure, setting up tiling, etc
                obj.zprvUpdateMergeWindowIfNecessary(); %computes merge based on prevailing CData, and displays figure
            else
                set(obj.hMergeFigs,'Visible','off');
            end
        end
        
        function set.channelsMergeFocusOnly(obj,val)
            val = obj.validatePropArg('channelsMergeFocusOnly',val);
            obj.channelsMergeFocusOnly = val;
        end
        
        %% Scanner properties
        function set.linesPerFrame(obj,val)
            obj.zprvAssertFocusOrIdle('linesPerFrame');
            
            val = obj.validatePropArg('linesPerFrame',val);
            
            % in acquisition mode focus a change of linesPerFrame should
            % stop the acquisition, change the parameter and restart
            rearmFocus = false;
            if strcmp(obj.acqState,'focus')
                obj.abort();
                rearmFocus = true;
            end
            
            %Side-effects
            if obj.scanSetPixelationPropFlag %#ok<*MCSUP>
                obj.linesPerFrame = val;
            else
                obj.zprpSetPixelationProp('linesPerFrame',val);
            end
            
            if ~obj.cfgLoading
                obj.zprpSetAcqAndScanParameters;
            end
            
            if rearmFocus
                obj.startFocus();
            end
        end
        
        function set.flybackLinesPerFrame(obj,val)
            obj.zprvAssertFocusOrIdle('pixelsPerLine');
            
            val = obj.validatePropArg('flybackLinesPerFrame',val);
            obj.flybackLinesPerFrame = val;
            
            %Side-effects
            if ~obj.cfgLoading
                obj.zprpSetAcqAndScanParameters;
            end
        end
        
        %         function set.acqNumFramesPerTrigger(obj,val)
        %             val = obj.validatePropArg('acqNumFramesPerTrigger',val);
        %             obj.acqNumFramesPerTrigger = val;
        %             %Side-effects
        %             obj.acqNumFrames = val;
        %         end
        
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
        
        function set.acqNumFrames(obj,val)
            obj.zprvAssertIdle('acqNumFrames');
            val = obj.validatePropArg('acqNumFrames',val);
            
            if isinf(val) && obj.fastZEnable
                obj.modelWarn('Cannot set acqNumFrames to Inf when fastZEnable=true');
                return;
            end
            obj.acqNumFrames = val;
            
            %Enforce FrameAcqFcnDecimationFactor constraint
            obj.acqNumFrames = obj.zprpApplyFAFDecFactorConstraint('acqNumFrames');
            
            %Dependencies
            obj.acqNumAveragedFrames = obj.acqNumAveragedFrames;
            obj.hFastZ.zprvFastZUpdateAODataNormalized();
            
            %Side Effects
            if obj.loggingFramesPerFileLock
                obj.loggingFramesPerFile = val;
            end
            obj.hFastZ.acqNumFrames = val;
            obj.hBeams.acqNumFrames = val;
        end
        
        function set.acqNumAveragedFrames(obj,val)
            obj.zprvAssertIdle('acqNumAveragedFrames');
            val = obj.validatePropArg('acqNumAveragedFrames',val);
            
            %Constrain by acqNumFrames: value must divide evenly into acqNumFrames
            if isinf(obj.acqNumFrames) || rem(obj.acqNumFrames,val)
                if val > 1
                    obj.modelWarn('Value of ''acqNumAveragedFrames'' must be integer sub-multiple of ''acqNumFrames''');
                end
                val = 1;
            end
            
            %Send logging average factor to resonant acq.
            obj.hAcq.loggingAverageFactor = val;
            obj.acqNumAveragedFrames = val;
            
            %Apply lock constraint, if applicable
            if obj.displayRollingAverageFactorLock
                obj.zprpLockDisplayRollAvgFactor();
            end
        end
        
        function set.acqsPerLoop(obj,val)
            val = obj.validatePropArg('acqsPerLoop',val);
            obj.acqsPerLoop = val;
        end
        
        function set.zoomFactor(obj,val)
            val = obj.validatePropArg('zoomFactor',val);
            obj.zoomFactor = val;
            %Side-effects
            obj.hScan.zoomFactor = val;
            obj.zoomChanged = true;
            obj.zzzEstimatePeriodClockPhase2();
        end
        
        function set.usrPropListCurrent(obj,val)
            assert(false,'Setting of usrPropListCurrent is not presently supported. It may be supported in the future.')
            
            %             obj.zprvAssertIdle('usrPropListCurrent');
            %             val = obj.validatePropArg('usrPropListCurrent',val);
            %
            %             propList = obj.mdlGetConfigProps()';
            %             [obj.usrPropListCurrent,goodIdxs] = intersect(val,propList);
            %             if length(goodIdxs) < length(val)
            %                 warning('SI5:invalidUsrProp',...
            %                     'Ignoring one or more properties that cannot be saved to a USR file.');
            %                 disp(setdiff(val,propList));
            %             end
        end
        
        %% Frame Buffer Properties
        
        function val = get.acqFrameBufferLength(obj)
            val = max(obj.acqFrameBufferLengthMin,obj.displayRollingAverageFactor * (obj.displayFrameBatchFactor / obj.frameAcqFcnDecimationFactor) + 1);
        end
        
        function set.acqFrameBufferLengthMin(obj,val)
            obj.zprvAssertIdle('acqFrameBufferLengthMin');
            val = obj.validatePropArg('acqFrameBufferLengthMin',val);
            obj.acqFrameBufferLengthMin = val;
        end
        
        
        %% Trigger/timing properties
        function set.triggerTypeExternal(obj,val)
            obj.zprvAssertIdle();
            val = obj.validatePropArg('triggerTypeExternal',val);
            obj.triggerTypeExternal = val;
            %Side effects
            obj.applyTriggerRouting();
            obj.hAcq.acqTriggerTypeExternal=logical(val);
            obj.hFastZ.acqTriggerTypeExternal=val;
        end
        
        function val = get.triggerExternalAvailable(obj)
            val = ~all(cellfun(@isempty,obj.triggerExternalTerminals));            
        end
        
        %         function set.triggerExternalAvailable(obj,val)
        %             val = obj.validatePropArg('triggerExternalAvailable',val);
        %             obj.triggerExternalAvailable = val;
        %
        %             %Side effects
        %             if ~obj.triggerExternalAvailable
        %                 obj.triggerTypeExternal = false;
        %             end
        %         end
        
        
        
        function set.triggerExternalTerminals(obj,val)
            obj.zprvAssertIdle();
            obj.triggerExternalTerminals = val;
            
            %side effects
            obj.applyTriggerRouting();
            %             triggerExternalAvailable = false;
            %             if ~isempty(val{1}) && ~strcmp(val{1},' ')
            %                 triggerExternalAvailable = true;
            %             end
            %             obj.triggerExternalAvailable = triggerExternalAvailable;
        end
        
        function set.triggerExternalEdges(obj,val)
            obj.zprvAssertIdle();
            obj.triggerExternalEdges = val;
            
            %side effects
            obj.applyTriggerRouting();
        end
        
        function set.loopAcqInterval(obj,val)
            obj.zprvAssertFocusOrIdle();
            val = obj.validatePropArg('loopAcqInterval',val);
            obj.loopAcqInterval = val;
        end
        
        %% Channel Properties
        function val = get.channelsInputRangeValues(obj)
            val=obj.hAcq.CHANNELS_INPUT_RANGES;
        end
        
        function val = get.channelsBitDepth(obj)
            val = obj.hAcq.bitDepth;
        end
        
        function val = get.channelsDataType(obj)
            val = 'uint16';
        end
        
        function val = get.channelOffsets(obj)
            val = obj.channelOffsets;
        end
        
        function val = get.channelsLUTRange(obj)
            n = obj.channelsBitDepth;
            %Set minimum LUT value at 10% of minimum range from framegrabber
            %Set maximum LUT value at 100% of maximum range from framegrabber
            val = [(-2^(n-1))*0.1 2^(n-1)-1];
        end
        
        function val = get.channelsSubtractOffset(obj)
            val = obj.channelsSubtractOffset;
        end
        
        %         function set.channelsActive(obj,val)
        %             val = obj.validatePropArg('channelsActive',val);
        %             assert(numel(val) <= obj.MAX_NUM_CHANNELS,'Exceeded max num channels'); %TODO: cleanup msg
        %
        %             obj.channelsActive = val;
        %             for i = 1:numel(obj.hFigs)
        %                 deactivate = isempty(find(obj.channelsActive==i,1));
        %                 if deactivate
        %                     set(obj.hFigs(i),'visible','off');
        %                 else
        %                     set(obj.hFigs(i),'visible','on');
        %                 end
        %             end
        %         end
        
        function set.chan1LUT(obj,val)
            val = obj.validatePropArg('chan1LUT',val);
            obj.chan1LUT = val;
            
            obj.zprpUpdateChanLUT(1,val);
        end
        
        function set.chan2LUT(obj,val)
            val = obj.validatePropArg('chan2LUT',val);
            obj.chan2LUT = val;
            
            obj.zprpUpdateChanLUT(2,val);
        end
        
        function set.chan3LUT(obj,val)
            val = obj.validatePropArg('chan3LUT',val);
            obj.chan3LUT = val;
            
            obj.zprpUpdateChanLUT(3,val);
        end
        
        function set.chan4LUT(obj,val)
            val = obj.validatePropArg('chan4LUT',val);
            obj.chan4LUT = val;
            
            obj.zprpUpdateChanLUT(4,val);
        end
        
        %% Logging Properties
        function set.loggingFilePath(obj,val)
            val = obj.validatePropArg('loggingFilePath',val);
            obj.loggingFilePath = val;
            
            obj.zprpUpdateLoggingFullFileName;
        end
        
        function set.loggingFileStem(obj,val)
            val = obj.validatePropArg('loggingFileStem',val);
            
            oldVal = obj.loggingFileStem;
            obj.loggingFileStem = val;
            
            obj.zprpUpdateLoggingFullFileName();
            
            if obj.loggingFileCounterAutoReset && ~strcmpi(val,oldVal)
                obj.loggingFileCounter = 1;
            end
        end
        
        function set.loggingFileCounter(obj,val)
            val = obj.validatePropArg('loggingFileCounter',val);
            obj.loggingFileCounter = val;
            obj.hAcq.loggingFileCounter = val;
            
            obj.zprpUpdateLoggingFullFileName;
        end
        
        function set.loggingFramesPerFile(obj,val)
            obj.zprvAssertFocusOrIdle('loggingFramesPerFile');
            %if ~obj.loggingFramesPerFileLock
            val = obj.validatePropArg('loggingFramesPerFile',val);
            obj.loggingFramesPerFile = val;
            
            %Enforce FrameAcqFcnDecimationFactor constraint
            obj.loggingFramesPerFile = obj.zprpApplyFAFDecFactorConstraint('loggingFramesPerFile');
            
            % Pass onto resonant acq object.
            obj.hAcq.loggingFramesPerFile = obj.loggingFramesPerFile;
            %else
            %    obj.modelWarn('Unable to set ''loggingFramesPerFile'' when ''loggingFramesPerFileLock''=true');
            %end
        end
        
        function set.loggingFramesPerFileLock(obj,val)
            obj.zprvAssertFocusOrIdle('loggingFramesPerFileLock');
            val = obj.validatePropArg('loggingFramesPerFileLock',val);
            
            %Dependencies
            if val
                obj.loggingFramesPerFileLock = false; %Force lock off to set value
                obj.loggingFramesPerFile = obj.acqNumFrames;
            end
            
            obj.loggingFramesPerFileLock = val;
            
            %side effects
            obj.hAcq.loggingFramesPerFileLock = obj.loggingFramesPerFileLock;
        end
        
        function set.loggingFileSubCounter(obj,val)
            obj.validatePropArg('loggingFileSubCounter',val);
            obj.loggingFileSubCounter = val;
            
            obj.zprpUpdateLoggingFullFileName();
        end
        
        function set.loggingEnable(obj,val)
            obj.zprvAssertIdle('loggingEnable');
            val = obj.validatePropArg('loggingEnable',val);
            obj.loggingEnable = val;
            
            %Side effects
            %Note that obj.hAcq.loggingEnable is set dynamically at time of startXXX
            obj.multiChannel = obj.zprpMultichannelStatus;
        end
        
        %% Motor properties
        function val = get.motorDimensionConfiguration(obj)
            if ~isempty(obj.hMotors)
                val = obj.hMotors.motorDimensionConfiguration;
            end
        end
        
        function set.motorDimensionConfiguration(obj,val)
            if ~isempty(obj.hMotors)
                obj.hMotors.motorDimensionConfiguration = val;
            end
        end
        
        function val = get.motorPosition(obj)
            if ~isempty(obj.hMotors)
                val = obj.hMotors.motorPosition;
            end
        end
        
        function val = get.motorSecondMotorZEnable(obj)
            if ~isempty(obj.hMotors)
                val = obj.hMotors.motorSecondMotorZEnable;
            end
        end
        
        function set.motorPosition(obj,val)
            if ~isempty(obj.hMotors)
                obj.hMotors.motorPosition = val;
            end
        end
        
        function set.motorSecondMotorZEnable(obj,val)
            if ~isempty(obj.hMotors)
                obj.hMotors.motorSecondMotorZEnable = val;
            end
            
            %Side Effects
            obj.stackClearStartEnd();
        end
        
        function motorSaveUserDefinedPositions(obj)
            obj.hMotors.motorSaveUserDefinedPositions();
        end
        
        %% Beam properties
        function set.beamNumBeams(obj,val)
            obj.hBeams.beamNumBeams = val;
        end
        
        function set.beamFlybackBlanking(obj,val)
            obj.hBeams.beamFlybackBlanking = val;
        end
        
        function set.acqBeamOverScan(obj,val)
            obj.hAcq.beamOverScan = [val 0];
        end
        
        function set.beamPowerLimits(obj,val)
            obj.hBeams.beamPowerLimits = val;
        end
        
        function set.beamLiveAdjust(obj,val)
            obj.hBeams.beamLiveAdjust = val;
        end
        
        function set.beamDirectMode(obj,val)
            %HACK: implement beamDirectMode actually, or remove
            assert(~val,'beamDirectMode not supported in present version');
            obj.hBeams.beamDirectMode = val;
        end
        
        function set.beamPowerUnits(obj,val)
            obj.hBeams.beamPowerUnits = val;
        end
        
        function set.beamPzAdjust(obj,val)
            obj.hBeams.beamPzAdjust = val; %scalar expand done by Beams adapter class
        end
        
        function set.beamLengthConstants(obj,val)
            obj.hBeams.beamLengthConstants = val;
        end
        
        function set.beamPowersDisplay(obj,val)
            obj.beamPowersDisplay = val;
        end
        
        function val = get.beamNumBeams(obj)
            val = obj.hBeams.beamNumBeams;
        end
        
        function val = get.beamFlybackBlanking(obj)
            val = obj.hBeams.beamFlybackBlanking;
        end
        
        function val = get.acqBeamOverScan(obj)
            val = obj.hAcq.beamOverScan(1);
        end
        
        function val = get.beamPowerLimits(obj)
            val = obj.hBeams.beamPowerLimits;
        end
        
        function val = get.beamLiveAdjust(obj)
            val = obj.hBeams.beamLiveAdjust;
        end
        
        function val = get.beamDirectMode(obj)
            val = obj.hBeams.beamDirectMode;
        end
        
        function val = get.beamPowerUnits(obj)
            val = obj.hBeams.beamPowerUnits;
        end
        
        function val = get.beamPzAdjust(obj)
            val = obj.hBeams.beamPzAdjust;
        end
        
        function val = get.beamLengthConstants(obj)
            val = obj.hBeams.beamLengthConstants;
        end
        
        function val = get.beamPowersDisplay(obj)
            val = obj.hBeams.beamPowers;
        end
        
        function set.beamPowers(obj,val)
            obj.hBeams.beamPowers = val;
        end
        
        function val = get.beamPowers(obj)
            val = obj.hBeams.beamPowers;
        end
        
        %% Stack properties
        
        function v = get.stackStartEndPointsDefined(obj)
            v = ~isnan(obj.stackZStartPos) & ~isnan(obj.stackZEndPos);
        end
        
        function set.stackUseStartPower(obj,val)
            obj.zprvAssertFocusOrIdle('stackUseStartPower');
            val = obj.validatePropArg('stackUseStartPower',val);
            obj.stackUseStartPower = val;
            
            %side effects
            obj.hBeams.stackUseStartPower = val;
        end
        
        function set.stackUserOverrideLz(obj,val)
            obj.zprvAssertFocusOrIdle('stackUserOverrideLz');
            val = obj.validatePropArg('stackUserOverrideLz',val);
            obj.stackUserOverrideLz = val;
            if val && ~obj.stackUseStartPower
                warning('SI5:stackUserOverrideLzWithoutStackUseStartPower',...
                    'StackUseStartPower is currently false.');
            end
            
            %Side effects
            obj.hBeams.stackUserOverrideLz = val;
            obj.hBeams.acqBeamLengthConstants = []; %Force recompute on next use
        end
        
        function set.stackStartPower(obj,val)
            obj.zprvAssertFocusOrIdle('stackStartPower');
            val = obj.validatePropArg('stackStartPower',val);
            
            obj.hBeams.stackStartPower = val;
        end
        
        function set.stackEndPower(obj,val)
            obj.zprvAssertFocusOrIdle('stackEndPower');
            val = obj.validatePropArg('stackEndPower',val);
            
            obj.hBeams.stackEndPower = val;
        end
        
        function val = get.stackStartPower(obj)
            val = obj.hBeams.stackStartPower;
        end
        
        function val = get.stackEndPower(obj)
            val = obj.hBeams.stackEndPower;
        end
        
        function set.stackReturnHome(obj,val)
            obj.zprvAssertFocusOrIdle('stackReturnHome');
            val = obj.validatePropArg('stackReturnHome',val);
            obj.stackReturnHome = val;
        end
        
        function set.stackStartCentered(obj,val)
            obj.zprvAssertFocusOrIdle('stackStartCentered');
            val = obj.validatePropArg('stackStartCentered',val);
            obj.stackStartCentered = val;
            %Side effects
            obj.hFastZ.stackStartCentered = val;
            obj.hBeams.stackStartCentered = val;
        end
        
        function set.stackNumSlices(obj,val)
            obj.zprvAssertFocusOrIdle('stackNumSlices');
            val = obj.validatePropArg('stackNumSlices',val);
            
            if ~obj.hMotors.motorHasMotor && ~obj.hFastZ.fastZAvailable
                obj.stackNumSlices = 1;
                return;
            end
            
            if isnan(val)
                val = 1;
            end
            
            obj.stackNumSlices = val;
            
            %Enforce FrameAcqFcnDecimationFactor constraint
            obj.stackNumSlices = obj.zprpApplyFAFDecFactorConstraint('stackNumSlices');
            
            %Side effects
            if obj.stackStartEndPointsDefined && ~obj.fastZEnable && val >= 2
                % Don't set stepsize to Inf if numSlices==1, this is
                % potentially dangerous. Leave it at its previous value.
                stepsize = obj.zprpStackComputeZStepSize();
                if ~isequaln(stepsize,obj.stackZStepSize)
                    obj.stackZStepSize = stepsize;
                end
            end
            
            %Side-effects
            obj.hFastZ.stackNumSlices = obj.stackNumSlices;
            obj.hBeams.stackNumSlices = obj.stackNumSlices;
            
            obj.hFastZ.zprvFastZUpdateAODataNormalized();
        end
        
        function set.stackZStepSize(obj,val)
            obj.zprvAssertFocusOrIdle('stackZStepSize');
            val = obj.validatePropArg('stackZStepSize',val);
            
            obj.stackZStepSize = val;
            if obj.stackStartEndPointsDefined && ~obj.fastZEnable
                numSlices = obj.zprpStackComputeNumSlices();
                obj.zprvSetInternal('stackNumSlices',numSlices);
            end
            
            %Side-effects
            obj.hFastZ.stackZStepSize = obj.stackZStepSize;
            obj.hBeams.stackZStepSize = obj.stackZStepSize;
            
            obj.hFastZ.zprvFastZUpdateAODataNormalized();
            
        end
        
        function set.stackZStartPos(obj,val)
            obj.zprvAssertFocusOrIdle('stackZStartPos');
            val = obj.validatePropArg('stackZStartPos',val);
            obj.stackZStartPos = val;
            if obj.stackStartEndPointsDefined && ~obj.fastZEnable && obj.stackNumSlices >= 2
                obj.stackZStepSize = obj.zprpStackComputeZStepSize();
            end
            obj.stackLastStartEndPositionSet = val; % does the right thing if val is nan (val==nan functionally means "clear the starting pos")
            
            %Side effects
            obj.hBeams.acqBeamLengthConstants = []; %Force recompute on next use
            %obj.hMotors.stackZStartPos = val;
            obj.hBeams.stackZStartPos = val;
        end
        
        function set.stackZEndPos(obj,val)
            obj.zprvAssertFocusOrIdle('stackZEndPos');
            val = obj.validatePropArg('stackZEndPos',val);
            obj.stackZEndPos = val;
            if obj.stackStartEndPointsDefined && ~obj.fastZEnable && obj.stackNumSlices >= 2
                obj.stackZStepSize = obj.zprpStackComputeZStepSize();
            end
            obj.stackLastStartEndPositionSet = val; % does the right thing if val is nan
            
            %Side effects
            obj.hBeams.acqBeamLengthConstants = []; %Force recompute on next use
            %obj.hMotors.stackZEndPos = val;
            obj.hBeams.stackZEndPos = val;
        end
        
        %% Fast Z Property Access Methods
        
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
        
        function set.fastZActive(obj,val)
            obj.fastZActive = val;
            % Side effects
            obj.hBeams.fastZActive = obj.fastZActive;
            obj.hFastZ.fastZActive = obj.fastZActive;
        end
        
        function val = get.fastZActive(obj)
            val = obj.fastZActive;
        end
        
        function set.fastZEnable(obj,val)
            obj.zprvAssertIdle('fastZEnable');
            val = obj.validatePropArg('fastZEnable',val);
            obj.fastZEnable = val;
            % Side effects
            obj.hBeams.fastZEnable = val;
            obj.hFastZ.fastZEnable = val;
        end
        
        %% Fast Z Dependent Property Methods
        function set.fastZAcquisitionDelay(obj,val)
            val = obj.validatePropArg('fastZSettlingTime',val); %Use same validator as fastZSettlingTime
            obj.hFastZ.fastZAcquisitionDelay = val;
        end
        
        function val = get.fastZAcquisitionDelay(obj)
            val = obj.hFastZ.fastZAcquisitionDelay;
        end
        
        function set.fastZImageType(obj,val)
            obj.zprvAssertIdle('fastZImageType');
            val = obj.validatePropArg('fastZImageType',val);
            % Side effects
            obj.hFastZ.fastZImageType = val;
            obj.hBeams.fastZImageType = val;
        end
        
        function val = get.fastZImageType(obj)
            val = obj.hFastZ.fastZImageType;
        end
        
        function set.fastZScanType(obj,val)
            obj.zprvAssertIdle('fastZScanType');
            val = obj.validatePropArg('fastZScanType',val);
            % Side effects
            obj.hFastZ.fastZScanType = val;
        end
        
        function val = get.fastZScanType(obj)
            val = obj.hFastZ.fastZScanType;
        end
        
        function set.fastZAllowLiveBeamAdjust(obj,val)
            obj.zprvAssertIdle('fastZAllowLiveBeamAdjust');
            val = obj.validatePropArg('fastZAllowLiveBeamAdjust',val);
            % Side effects
            obj.hFastZ.fastZAllowLiveBeamAdjust = val;
        end
        
        function val = get.fastZAllowLiveBeamAdjust(obj)
            val = obj.hFastZ.fastZAllowLiveBeamAdjust;
        end
        
        function set.fastZSettlingTime(obj,val)
            obj.zprvAssertIdle('fastZSettlingTime');
            val = obj.validatePropArg('fastZSettlingTime',val);
            obj.hFastZ.fastZSettlingTime = val;
        end
        
        function val = get.fastZSettlingTime(obj)
            val = obj.hFastZ.fastZSettlingTime;
        end
        
        function set.fastZDiscardFlybackFrames(obj,val)
            obj.zprvAssertIdle('fastZDiscardFlybackFrames');
            val = obj.validatePropArg('fastZDiscardFlybackFrames',val);
            % Side effects
            obj.hFastZ.fastZDiscardFlybackFrames = val;
        end
        
        function val = get.fastZDiscardFlybackFrames(obj)
            val = obj.hFastZ.fastZDiscardFlybackFrames;
        end
        
        function set.fastZFramePeriodAdjustment(obj,val)
            obj.zprvAssertIdle('fastZFramePeriodAdjustment');
            val = obj.validatePropArg('fastZFramePeriodAdjustment',val);
            % Side effects
            obj.hFastZ.fastZFramePeriodAdjustment = val;
        end
        
        function val = get.fastZFramePeriodAdjustment(obj)
            val = obj.hFastZ.fastZFramePeriodAdjustment;
        end
        
        function set.fastZUseAOControl(obj,val)
            obj.zprvAssertIdle('fastZUseAOControl');
            val = obj.validatePropArg('fastZUseAOControl',val);
            % Side effects
            obj.hFastZ.fastZUseAOControl = val;
        end
        
        function val = get.fastZUseAOControl(obj)
            val = obj.hFastZ.fastZUseAOControl;
        end
        
        function set.fastZNumDiscardFrames(obj,val)
            obj.mdlDummySetProp(val,'fastZNumDiscardFrames');
            % Side effects
            %obj.hFastZ.fastZNumDiscardFrames = obj.fastZNumDiscardFrames;
            obj.hBeams.fastZNumDiscardFrames = obj.fastZNumDiscardFrames;
        end
        
        function val = get.fastZNumDiscardFrames(obj)
            val = obj.hFastZ.fastZNumDiscardFrames;
        end
        
        function set.fastZNumVolumes(obj,val)
            obj.zprvAssertIdle('fastZNumVolumes');
            val = obj.validatePropArg('fastZNumVolumes',val);
            % Side effects
            obj.hFastZ.fastZNumVolumes = val;
            obj.hBeams.fastZNumVolumes = val;
        end
        
        function val = get.fastZNumVolumes(obj)
            val = obj.hFastZ.fastZNumVolumes;
        end
        
        function set.fastZVolumesDone(obj,val)
            obj.hFastZ.fastZVolumesDone = val;
        end
        
        function val = get.fastZVolumesDone(obj)
            val = obj.hFastZ.fastZVolumesDone;
        end
        
        function set.fastZPeriod(obj,val)
            obj.hFastZ.fastZPeriod = val;
        end
        
        function val = get.fastZPeriod(obj)
            val = obj.hFastZ.fastZPeriod;
        end
        
        function set.fastZFillFraction(obj,val)
            obj.hFastZ.fastZFillFraction = val;
        end
        
        function val = get.fastZFillFraction(obj)
            val = obj.hFastZ.fastZFillFraction;
        end
        
        
        %% PMT properties
        function set.bscope2PmtPowersOn(obj, val)
            if obj.bscope2PmtValsSet
                if obj.hPMTs.Mod2ContSet
                    obj.bscope2PmtPowersOn = logical(val);
                else
                    obj.hPMTs.powersOn = logical(val);
                end
            end
        end
        
        function set.bscope2PmtGains(obj, val)
            if obj.bscope2PmtValsSet
                if obj.hPMTs.Mod2ContSet
                    obj.bscope2PmtGains = val;
                else
                    obj.hPMTs.gains = val;
                end
            end
        end
        
        function set.bscope2PmtTripped(obj, val)
            if obj.hPMTs.Mod2ContSet
                obj.bscope2PmtTripped = val;
            end
        end
        
        
        %% BScope2 properties
        function set.bscope2FlipperMirrorPosition(obj, val)
            if ~isempty(obj.hBScope2)
                if obj.hBScope2.lscInitSuccessful
                    switch val
                        case {'camera' 'pmt'}
                            obj.bscope2FlipperMirrorPosition = val;
                            obj.hBScope2.flipperMirrorPosition = val;

                        otherwise
                            assert(false, 'Invalid flipper mirror position requested.');
                    end
                end
            end
        end
        
        function set.bscope2GalvoResonantMirrorInPath(obj, val)
            if ~isempty(obj.hBScope2)
                if obj.hBScope2.lscInitSuccessful
                    validateattributes(val,{'logical' 'numeric'},{'scalar'});
                    obj.bscope2GalvoResonantMirrorInPath = val;
                    obj.hBScope2.galvoResonantMirrorInPath = val;
                end
            end
        end
        
        function set.bscope2GalvoGalvoMirrorInPath(obj, val)
            if ~isempty(obj.hBScope2)
                if obj.hBScope2.lscInitSuccessful
                    validateattributes(val,{'logical' 'numeric'},{'scalar'});
                    obj.bscope2GalvoGalvoMirrorInPath = val;
                    obj.hBScope2.galvoGalvoMirrorInPath = val;
                end
            end
        end
        
        function v = get.bScope2RotationAngle(obj)
            v=0;
            if ~isempty(obj.hBScope2)
                if obj.hBScope2.lscInitSuccessful
                    v = obj.hBScope2.rotationAngleAbsolute;
                end
            end
        end
        
        function v = get.bscope2ScanAlign(obj)
            v=0;
            if ~isempty(obj.hBScope2)
                v = obj.hBScope2.scanAlign;
            end
        end
        
        function set.bscope2ScanAlign(obj, val)
            if ~isempty(obj.hBScope2)
                obj.validatePropArg('bscope2ScanAlign', val);
                obj.hBScope2.scanAlign = val;
            end
        end
        
        
        %% Display methods
        function val = get.displayShowCrosshairTrue(obj)
            val = obj.displayShowCrosshair && numel(obj.displayFrameBatchSelection) <= 1;
        end
        
        function set.displayShowCrosshair(obj,val)
            val = obj.validatePropArg('displayShowCrosshair',val);
            obj.displayShowCrosshair = val;
            
            %Dependencies
            obj.displayShowCrosshairTrue = obj.displayShowCrosshairTrue;
        end
        
        function set.displayShowCrosshairTrue(obj,val)
            
            %TODO: This logic would ideally be in a DependsOn 'callback', rather than in a prop setter, avoiding eigenset operations in all the setters which drive this operation
            %TODO: crosshair + merge
            for i=1:obj.MAX_NUM_CHANNELS
                hFig = obj.hFigs(i);
                hAx = obj.hAxes{i}; %Handle to axes(s) associated with current channel
                
                %Delete any existing crosshair objects
                hCross = findall(hFig,'Tag','ImageCrosshair');
                delete(hCross);
                
                if val %Add crosshair
                    
                    %Get normalized axes posn
                    axUnits = get(hAx,'Units');
                    set(hAx,'Units','normalized');
                    axPosnNorm = get(hAx,'Position');
                    set(hAx,'Units',axUnits);
                    
                    %Create annotation spanning size of axes
                    set(0,'CurrentFigure',obj.hFigs(i));
                    annotation('line',repmat((axPosnNorm(1) + axPosnNorm(3))/2,1,2), [axPosnNorm(2) axPosnNorm(2) + axPosnNorm(4)],'Tag','ImageCrosshair','Color',[1 1 1],'LineWidth',1); %Vertical line
                    annotation('line', [axPosnNorm(1) axPosnNorm(1) + axPosnNorm(3)],repmat((axPosnNorm(2) + axPosnNorm(4))/2,1,2),'Tag','ImageCrosshair','Color',[1 1 1],'LineWidth',1); %Horizontal line
                end
            end
        end
        
        function set.displayDecimationFactor(obj,val)
            obj.displayDecimationFactor = val;
            
            %side effects
            obj.hAcq.displayDecimationFactor = val;
        end
        
        function set.displayBatchingFactor(obj,val)
            obj.displayBatchingFactor = val;
            
            %side effects
            obj.hAcq.displayBatchingFactor = val;
        end
        
        function set.displayRollingAverageFactor(obj,val)
            obj.zprvAssertFocusOrIdle('displayRollingAverageFactor');
            
            %Enforce displayRollingAverageFactorLock constraint
            if obj.displayRollingAverageFactorLock
                allowedVal = obj.zprpLockDisplayRollAvgFactor();
                if val ~= allowedVal
                    return;
                end
            end
            
            %Proceed with set
            val = obj.validatePropArg('displayRollingAverageFactor',val); %allow while running
            
            obj.displayRollingAverageFactor = val;
            
            %Dependencies
            
            if obj.displayFrameBatchFactorLock && obj.displayFrameBatchFactor ~= (val * obj.frameAcqFcnDecimationFactor)
                obj.displayFrameBatchFactor = (val * obj.frameAcqFcnDecimationFactor);
            end
            
            obj.zprvResetBuffersIfFocusing();
        end
        
        function set.displayRollingAverageFactorLock(obj,val)
            val = obj.validatePropArg('displayRollingAverageFactorLock',val); %Allow while running
            obj.displayRollingAverageFactorLock = val;
            
            %Dependencies
            if val
                obj.zprpLockDisplayRollAvgFactor();
            end
        end
        
        function set.displayFrameBatchFactor(obj,val)
            %Enforce displayFrameBatchFactorLock constraint
            if obj.displayFrameBatchFactorLock && val ~= (obj.displayRollingAverageFactor * obj.frameAcqFcnDecimationFactor)
                return;
            end
            
            %Proceed with set
            val = obj.validatePropArg('displayFrameBatchFactor',val);
            obj.displayFrameBatchFactor = val;
            
            %Enforce FrameAcqFcnDecimationFactor constraint
            obj.displayFrameBatchFactor = obj.zprpApplyFAFDecFactorConstraint('displayFrameBatchFactor');
            
            %Dependencies
            if obj.displayFrameBatchSelectLast && ~isequal(val,obj.displayFrameBatchSelection)
                obj.displayFrameBatchSelection = val;
            else
                obj.displayFrameBatchSelection = obj.displayFrameBatchSelection;
            end
            obj.zprvResetBuffersIfFocusing();
            
        end
        
        function set.displayFrameBatchFactorLock(obj,val)
            val = obj.validatePropArg('displayFrameBatchFactorLock',val);
            obj.displayFrameBatchFactorLock = val;
            
            %Dependencies
            if val && obj.displayFrameBatchFactor ~= (obj.displayRollingAverageFactor * obj.frameAcqFcnDecimationFactor)
                obj.displayFrameBatchFactor = (obj.displayRollingAverageFactor * obj.frameAcqFcnDecimationFactor);
            end
        end
        
        function set.displayFrameBatchSelection(obj,val)
            %Enforce displayFrameBatchSelectLast constraint
            if obj.displayFrameBatchSelectLast && ~isequal(val,obj.displayFrameBatchFactor)
                return;
            end
            
            val = obj.validatePropArg('displayFrameBatchSelection',val);
            
            %Constrain by displayFrameBatchFactor & set
            val(val > obj.displayFrameBatchFactor) = []; %TODO: Ideally use 'Range' attribute with property replacement to 'automatically' enforce this constraint
            
            changeVal = ~isequal(val,obj.displayFrameBatchSelection);
            obj.displayFrameBatchSelection = val;
            
            %Enforce FrameAcqFcnDecimationFactor constraint
            obj.displayFrameBatchSelection = obj.zprpApplyFAFDecFactorConstraint('displayFrameBatchSelection');
            
            %Dependencies
            if changeVal
                obj.zprvResetDisplayFigs(obj.channelsDisplay,obj.channelsMergeEnable);
                obj.displayShowCrosshairTrue = obj.displayShowCrosshairTrue;
                
                obj.zprvResetBuffersIfFocusing();
            end
        end
        
        function set.displayFrameBatchSelectLast(obj,val)
            val = obj.validatePropArg('displayFrameBatchSelectLast',val);
            obj.displayFrameBatchSelectLast = val;
            
            %Dependencies
            if val && ~isequal(obj.displayFrameBatchSelection,obj.displayFrameBatchFactor)
                obj.displayFrameBatchSelection = obj.displayFrameBatchFactor;
            end
        end
        
        
        function set.focusDuration(obj,val)
            obj.zprvAssertIdle('focusDuration');
            obj.validatePropArg('focusDuration',val);
            obj.focusDuration = val;
        end
        
        function channelsReadOffsets(obj)
            %Measure digitizer offset voltage on all channels - with
            %shutter closed, scanner parked, beam blocked. Updates
            %channelOffsets property.
            
            
            if ~obj.mdlInitialized
                return;
            end
            
            assert(strcmpi(obj.acqState,'idle'),'Cannot read channel offsets during ongoing acquisition');
            
            ME = [];
            
            try
                tempOffsets = zeros(1,obj.MAX_NUM_CHANNELS);
                if ~obj.mdfData.simulated
                    for i=1:100
                        tempOffsets = tempOffsets + double(obj.hAcq.rawAdcOutput);
                    end
                end
                obj.channelOffsets = int16(tempOffsets / 100);
                
            catch MEtemp
                ME = MEtemp;
            end
            
            obj.acqState = 'idle';
            
            if ~isempty(ME)
                ME.rethrow();
            end
        end
        
        function saveDisplayAs(obj,fname)
            %Save last displayed image(s) on channel display figure(s) to
            %multi-frame TIF file. Typically used to save image acquired
            %using Focus mode.
            
            imageData = zeros(obj.linesPerFrame,obj.pixelsPerLine,length(find(obj.channelsDisplay)),obj.channelsDataType);
            chanCount = 1;
            for i=1:length(obj.channelsDisplay)
                chanIdx = obj.channelsDisplay(i);
                imageData(:,:,chanCount) = get(obj.hImages{chanIdx}(1),'CData'); %TODO: Allow saving of tiled displays
                chanCount = chanCount+1;
            end
            
            if nargin < 2 || isempty(fname)
                startPath = obj.loggingFilePath;
                if isempty(startPath)
                    startPath = most.idioms.startPath();
                end
                [f,p] = uiputfile('*.tif','Save Image As...',startPath);
                if isnumeric(f)
                    return;
                end
                
                if exist(fullfile(p,f),'file')
                    resp = questdlg('File already exists. Overwrite?','File Already Exists','Overwrite','Cancel','Cancel');
                    
                    if strcmpi(resp,'Cancel')
                        return;
                    end
                end
            end
            
            %Write the file
            for i=1:length(obj.channelsDisplay)
                if i == 1
                    writeMode = 'Overwrite';
                else
                    writeMode = 'Append';
                end
                
                imwrite(imageData(:,:,i),fullfile(p,f),'WriteMode',writeMode);
            end
        end
    end
    
    %% PUBLIC METHODS (Scan Parameter Caching)
    methods
        function scanParamResetToBase(obj,params)
            % Set ROI scan parameters (zoom,scanAngleMultiplier) to cached
            % values (set via scanParamSetCache()). If no values are
            % cached, restores the scan parameters stored in currently
            % loaded CFG file.
            
            % params: <OPTIONAL> String cell array specifically which parameter(s) to reset to BASE or CFG-file value(s)
            
            if nargin > 1
                cachedProps = params;
                assert(iscellstr(cachedProps) && all(ismember(cachedProps,obj.SCAN_PARAM_CACHE_PROPS)));
            else
                cachedProps = obj.SCAN_PARAM_CACHE_PROPS;
            end
            
            if ~isempty(obj.scanParamCache)
                for i=1:length(cachedProps)
                    obj.(cachedProps{i}) = obj.scanParamCache.(cachedProps{i});
                end
            else
                cfgfile = obj.cfgFilename;
                
                resetFailProps = {};
                if exist(cfgfile,'file')==2
                    cfgPropSet = obj.mdlLoadPropSetToStruct(cfgfile);
                    
                    for i=1:length(cachedProps)
                        if isfield(cfgPropSet,cachedProps{i})
                            obj.(cachedProps{i}) = cfgPropSet.(cachedProps{i});
                        else
                            resetFailProps{end+1} = cachedProps{i};   %#ok<AGROW>
                        end
                    end
                end
                
                if ~isempty(resetFailProps)
                    warning('SI5:scanParamNotReset',...
                        'One or more scan parameters (%s) were not reset to base or config file value.',most.util.toString(resetFailParams));
                    
                end
            end
        end
        
        function scanParamSetBase(obj)
            %Caches scan parameters (zoom, scan angle multiplier) which can be recalled by scanParamResetToBase() method
            
            cachedProps = obj.SCAN_PARAM_CACHE_PROPS;
            for i=1:length(cachedProps)
                obj.scanParamCache.(cachedProps{i}) = obj.(cachedProps{i});
            end
        end
        
    end
    
    %% PUBLIC METHODS (Stack Operations)
    methods
        function stackSetStackStart(obj)
            %Save curent motor Z position and beam power level as stack start point
            obj.stackZStartPos = obj.hMotors.stackCurrentMotorZPos;
            obj.stackStartPower = obj.hBeams.beamPowers;
        end
        
        function stackSetStackEnd(obj)
            %Save curent motor Z position and beam power level as stack end point
            
            obj.stackZEndPos = obj.hMotors.stackCurrentMotorZPos;
            obj.stackEndPower = obj.hBeams.beamPowers;
        end
        
        function stackClearStartEnd(obj)
            %Clear any saved stack start & end points
            
            obj.stackZStartPos = nan;
            obj.stackStartPower = nan; % todo multibeam
            obj.stackZEndPos = nan;
            obj.stackEndPower = nan; % todo multibeam
        end
        
        function stackClearEnd(obj)
            %Clear saved stack end point (if set)
            
            obj.stackZEndPos = nan;
            obj.stackEndPower = nan; % todo multibeam
        end
    end
    
    %% PUBLIC METHODS (Trigger Operations)
    methods
        function generateAcqStartTrigger(obj)
            obj.hAcq.generateSoftwareAcqTrigger();
        end
        
        function generateAcqStopTrigger(obj)
            obj.hAcq.generateSoftwareAcqStopTrigger();
        end
        
        function generateNextFileMarkerTrigger(obj)
            obj.hAcq.generateSoftwareNextFileMarkerTrigger();
        end
    end
    
    %% CLASS DATA FILE
    methods
        function zprvEnsureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('scanPhaseMap',obj.scanPhaseMap));
            obj.ensureClassDataFile(struct('lastUsrFile',''));
            obj.ensureClassDataFile(struct('lastConfigFilePath',''));
            obj.ensureClassDataFile(struct('lastFastConfigFilePath',''));
        end
    end
    
    %% USR/CFG/FASTCFG API (public)
    methods
        function val = get.usrCfgFileVarName(obj)
            val = regexprep(sprintf('%s__configFileName',class(obj)),'\.','_');
        end
        
        function usrSaveUsr(obj)
            % Save 1) current values of USR property subset, 2) current GUI
            % layout, and 3) currently loaded CFG file (if any) to
            % currently specified usrFilename
            obj.usrSaveUsrAs(obj.usrFilename);
        end
        
        function usrSaveUsrAs(obj,fname,cfgfname,cullExtraProps)
            % Save 1) current values of USR property subset, 2) current GUI
            % layout, and 3) currently loaded CFG file (if any) to
            % specified or selected USR filename
            
            % fname (optional): usr filename. If unspecified or empty, uiputfile is run.
            % cfgfname (optional): cfg filename to be associated with specified usr file. If empty or not specified, obj.cfgFilename is used.
            if nargin < 2
                fname = [];
            end
            if nargin < 3
                cfgfname = obj.cfgFilename;
            end
            if nargin < 4
                cullExtraProps = false;
            end
            
            obj.zprvAssertIdle('usrSaveUsrAs');
            
            % Handle cross caching with cfg file path
            % obj.ensureClassDataFile(struct('lastUsrFile',most.idioms.startPath));
            lastPath = obj.getClassDataVar('lastUsrFile');
            if isempty(lastPath)
                lastPath = obj.getClassDataVar('lastConfigFilePath');
                
                if isempty(lastPath)
                    lastPath = most.idioms.startPath;
                end
            end
            
            usrFileName = obj.zprvUserCfgFileHelper(fname,...
                @()uiputfile('%.usr','Save Usr As...',lastPath),...
                @(path,file,fullfile)assert(exist(path,'dir')==7,'Specified directory does not exist.'));
            if isempty(usrFileName) % usr cancelled
                return;
            end
            obj.setClassDataVar('lastUsrFile',usrFileName);
            
            % save usr subset
            obj.mdlSavePropSetFromList([obj.usrPropListCurrent; obj.VERSION_PROP_NAMES],usrFileName,cullExtraProps);
            
            % save layout
            if ~isempty(obj.hController)
                assert(isscalar(obj.hController));
                obj.hController{1}.ctlrSaveGUILayout(usrFileName);
            end
            
            % save associated cfgfile
            cfgfileVarname = obj.usrCfgFileVarName;
            tmp.(cfgfileVarname) = cfgfname; %#ok<STRNU>
            save(usrFileName,'-struct','tmp','-mat','-append');
            
            obj.usrFilename = usrFileName;
        end
        
        function usrLoadUsr(obj,fname)
            % Load contents of specifed or selected USR file, updating 1)
            % values of USR property subset, 2) GUI layout, and 3)
            % currently loaded CFG file
            
            if nargin < 2
                fname = [];
            end
            
            obj.zprvAssertIdle('usrLoadUsr');
            
            try
                % Handle cross caching with cfg file path
                % obj.ensureClassDataFile(struct('lastUsrFile',most.idioms.startPath));
                lastPath = obj.getClassDataVar('lastUsrFile');
                if isempty(lastPath)
                    lastPath = obj.getClassDataVar('lastConfigFilePath');
                    
                    if isempty(lastPath)
                        lastPath = most.idioms.startPath;
                    end
                end
                
                usrFileName = obj.zprvUserCfgFileHelper(fname,...
                    @()uigetfile('%.usr','Load Usr File...',lastPath),...
                    @(path,file,fullfile)assert(exist(fullfile,'file')==2,'Specified file does not exist.'));
                if isempty(usrFileName) % usr cancelled
                    return;
                end
                obj.setClassDataVar('lastUsrFile',usrFileName);
                
                wb = waitbar(0,'Loading User Settings ...');
                
                % load usr propset
                usrPropSetFull = obj.mdlLoadPropSetToStruct(usrFileName);
                usrPropSetApply = rmfield(usrPropSetFull,intersect(fieldnames(usrPropSetFull),obj.VERSION_PROP_NAMES));
                
                % set usr* state
                obj.usrFilename = usrFileName;
                %obj.usrPropListCurrent = fieldnames(usrPropSetApply); %Removed for SI5 - not presently supporting settable/variable usrPropListCurrent
                
                % load associated cfgfilename
                usrSpecifiedCfgFilename = [];
                s = load(usrFileName,'-mat');
                if isfield(s,obj.usrCfgFileVarName)
                    usrSpecifiedCfgFilename = s.(obj.usrCfgFileVarName);
                end
                
                waitbar(0.25,wb);
                
                % cfgFile handling
                % * If the usrFile specifies a cfgFile and it exists/loads
                % properly, that cfgfile will be used.
                % * If the usrFile specifies a cfgFile and it either doesn't
                % exist or doesn't load, no cfgFile will be used.
                % * If the usrFile doesn't specify a cfgFile (or specifies an
                % empty cfgFile), the current cfgFile will be used.
                if ~isempty(usrSpecifiedCfgFilename)
                    if exist(usrSpecifiedCfgFilename,'file')==2
                        cfgfilename = usrSpecifiedCfgFilename;
                    else
                        warning('SI5:fileNotFound',...
                            'Config file ''%s'' specified in usr file ''%s'' was not found.',usrSpecifiedCfgFilename,usrFileName);
                        cfgfilename = '';
                    end
                elseif ~isempty(obj.cfgFilename) && exist(obj.cfgFilename,'file')==2
                    cfgfilename = obj.cfgFilename;
                else
                    % no cfg file associated with USR file; no cfg file currently loaded
                    cfgfilename = '';
                end
                
                waitbar(0.5,wb);
                
                % apply usr, cull if necessary
                [~,anyPropNotFound] = obj.mdlApplyPropSet(usrPropSetApply);
                if anyPropNotFound
                    button = questdlg('Usr file contains properties not currently recognized by ScanImage (likely deprecated). These properties will be removed the next time the usr file is saved. Would you like to save now?',...
                        'Unused Properties','Yes','No','No');
                    if strcmp(button,'Yes')
                        cullExtraProps = true; %cull props not part of current SI5 definition
                        obj.usrSaveUsrAs(obj.usrFilename, cullExtraProps); 
                    end
                end
                
                
                % cfg state
                if ~isempty(cfgfilename)
                    try
                        obj.hAcq.delayMaskComputation = true;
                        obj.cfgLoadConfig(cfgfilename);
                        obj.hAcq.delayMaskComputation = false;
                    catch %#ok<CTCH>
                        warning('SI5:errLoadingConfig',...
                            'Error loading config file ''%s''.',cfgfilename);
                    end
                end
                
                waitbar(0.75,wb);
                
                % update layout
                if ~isempty(obj.hController)
                    assert(isscalar(obj.hController));
                    obj.hController{1}.ctlrLoadGUILayout(usrFileName);
                end
                waitbar(1,wb);
                
            catch ME
                most.idioms.reportError(ME);
            end
            % display/hide channel windows that are currently active
            obj.channelsDisplay = obj.channelsDisplay;
            delete(wb);
        end
        
        function cfgSaveConfig(obj)
            %Save values of (most) publicly settable properties of this class to currently loaded CFG file
            obj.cfgSaveConfigAs(obj.cfgFilename);
        end
        
        function cfgSaveConfigAs(obj,fname,cullExtraProps)
            %Save values of (most) publicly settable properties of this class to specified or selected CFG file
            
            % Save configuration to file and update .cfgFilename.
            % * If fname is not specified, uiputfile is called to get a file.
            % * If fname exists, config info is appended/overwritten to fname.
            % * If fname does not exist, it is created.
            if nargin < 2
                fname = [];
            end
            
            obj.zprvAssertIdle('cfgSaveConfigAs');
            
            % Handle cross caching with usr file path
            % obj.ensureClassDataFile(struct('lastConfigFilePath',most.idioms.startPath));
            lastPath = obj.getClassDataVar('lastConfigFilePath');
            if isempty(lastPath)
                [lastPath,~,~] = fileparts(obj.getClassDataVar('lastUsrFile'));
                
                if isempty(lastPath)
                    lastPath = most.idioms.startPath;
                end
            end
            
            cfgfilename = obj.zprvUserCfgFileHelper(fname,...
                @()uiputfile('*.cfg','Save Config As...',lastPath),...
                @(path,file,fullfile)assert(exist(path,'dir')==7,'Specified directory does not exist.'));
            if isempty(cfgfilename) % user cancelled
                return;
            end
            obj.setClassDataVar('lastConfigFilePath',fileparts(cfgfilename));
            
            % save it
            if nargin < 3
                cullExtraProps = false;
            end
                
            %HACK: Identify dependt props to include in CFG file
            % This is needed for the pre sub-component architecture that
            % has duplicate SI5-level props which are Dependent and which
            % delegate to an informal subcomponent (adapter) class
            depCfgProps =  {'fillFractionTime'; ...
                            'beamPowers'; ...
                            'beamPzAdjust'; ...
                            'beamLengthConstants'; ...
                            'beamFlybackBlanking'; ...
                            'fastZImageType'; ...
                            'fastZScanType'; ...
                            'fastZDiscardFlybackFrames'; ...
                            'fastZFramePeriodAdjustment'; ...
                            'fastZAcquisitionDelay'};                            
            
            cfgProps = [obj.mdlDefaultConfigProps; obj.VERSION_PROP_NAMES; depCfgProps];
            cfgProps = setdiff(cfgProps, [obj.usrPropListCurrent; 'cfgFilename']);
            
            obj.mdlSavePropSetFromList(cfgProps,cfgfilename,cullExtraProps);
            obj.cfgFilename = cfgfilename;
        end
        
        function cfgLoadConfig(obj,fname)
            % Load contents of specifed or selected CFG file, updating
            % values of most publicly settable properties of this class.
            
            % * If fname is not specified, uigetfile is called to get a file.
            % * Config info is appended/overwritten to fname.
            
            if nargin < 2
                fname = [];
            end
            
            obj.zprvAssertIdle('cfgLoadConfig');
            
            try
                % Handle cross caching with usr file path
                % obj.ensureClassDataFile(struct('lastConfigFilePath',most.idioms.startPath));
                lastPath = obj.getClassDataVar('lastConfigFilePath');
                if isempty(lastPath)
                    [lastPath,~,~] = fileparts(obj.getClassDataVar('lastUsrFile'));
                    
                    if isempty(lastPath)
                        lastPath = most.idioms.startPath;
                    end
                end
            
                cfgfilename = obj.zprvUserCfgFileHelper(fname,...
                    @()uigetfile('*.cfg','Load Config...',lastPath),...
                    @(path,file,fullfile)assert(exist(fullfile,'file')==2,'Specified file does not exist.'));
                if isempty(cfgfilename)
                    return;
                end
                obj.setClassDataVar('lastConfigFilePath',fileparts(cfgfilename));
                
                wb = waitbar(0,'Loading Configuration ...');
                
                % At the moment, this just loads the cfg, ignoring possible
                % need to reload the USR, or parts of the USR.
                cfgPropSet = obj.mdlLoadPropSetToStruct(cfgfilename);
                waitbar(0.25,wb);
                cfgPropSetApply = rmfield(cfgPropSet,intersect(fieldnames(cfgPropSet),obj.VERSION_PROP_NAMES));
                waitbar(0.5,wb);
                obj.cfgLoading = true;
                [~,anyPropNotFound] = obj.mdlApplyPropSet(cfgPropSetApply);
                obj.cfgLoading = false;
                obj.zprpSetAcqAndScanParameters;
                waitbar(0.75,wb);
                obj.cfgFilename = cfgfilename;
                waitbar(1,wb);
                
                if anyPropNotFound
                    button = questdlg('Cfg file contains properties not currently recognized by ScanImage (likely deprecated). These properties will be removed the next time the cfg file is saved. Would you like to save now?',...
                        'Unused Properties','Yes','No','No');
                    if strcmp(button,'Yes')
                        cullExtraProps = true; %cull props not part of current SI5 definition
                        obj.cfgSaveConfigAs(obj.cfgFilename, cullExtraProps); 
                    end
                end
                
            catch ME
                most.idioms.reportError(ME);
            end
            delete(wb);
        end
        
        function fastCfgSetConfigFile(obj,idx,fname)
            % Specify/select a CFG file to a numbered FastCFG,
            % for subsequent rapid (cached) loading with fastCfgLoadConfig()
            validateattributes(idx,{'numeric'},{'scalar' 'nonnegative' 'integer' '<=' obj.FAST_CFG_NUM_CONFIGS});
            
            if nargin < 3
                fname = [];
            end
            
            % Handle cross caching with cfg file path
            % obj.ensureClassDataFile(struct('lastFastConfigFilePath',most.idioms.startPath));
            lastPath = obj.getClassDataVar('lastFastConfigFilePath');
            if isempty(lastPath)
                lastPath = obj.getClassDataVar('lastConfigFilePath');
                
                if isempty(lastPath)
                    [lastPath,~,~] = fileparts(obj.getClassDataVar('lastUsrFile'));
                    
                    if isempty(lastPath)
                        lastPath = most.idioms.startPath;
                    end
                end
            end
            
            cfgfilename = obj.zprvUserCfgFileHelper(fname,...
                @()uigetfile('*.cfg','Select Config File',lastPath),...
                @(path,file,fullfile)assert(exist(fullfile,'file')==2,'Specified file does not exist.'));
            if isempty(cfgfilename) % user cancelled
                return;
            end
            obj.setClassDataVar('lastFastConfigFilePath',fileparts(cfgfilename));
            obj.fastCfgCfgFilenames{idx} = cfgfilename;
        end
        
        function fastCfgLoadConfig(obj,idx,tfBypassAutostart)
            %Load CFG file settings cached at a numbered FastCFG, autostarting acquisition if appropriate.
            
            % Load the idx'th fast config and autostart if
            % appropriate.
            % tfBypassAutostart: optional bool, defaults to false. If true, the
            % fastConfiguration is loaded but not autostarted, even if
            % autostart is on.
            if nargin < 3
                tfBypassAutostart = false;
            end
            
            obj.zprvAssertIdle('fastCfgLoadConfig');
            
            validateattributes(idx,{'numeric'},{'scalar' 'nonnegative' 'integer' '<=' obj.FAST_CFG_NUM_CONFIGS});
            validateattributes(tfBypassAutostart,{'logical'},{'scalar'});
            
            fname = obj.fastCfgCfgFilenames{idx};
            if isempty(fname)
                warning('SI5:fastCfgLoadConfig:noConfigFileLoaded',...
                    'No config file loaded for fast configuration #%d.',idx);
                return;
            end
            if exist(fname,'file')~=2
                warning('SI5:fastCfgLoadConfig:fileNotFound',...
                    'Config file ''%s'' not found.',fname);
                return;
            end
            
            if ~tfBypassAutostart && obj.fastCfgAutoStartTf(idx)
                obj.cfgLoadConfig(fname);
                autoStartType = obj.fastCfgAutoStartType{idx};
                switch autoStartType
                    case 'focus'
                        obj.startFocus();
                    case 'grab'
                        obj.startGrab();
                    case 'loop'
                        obj.startLoop();
                    otherwise
                        obj.cfgUnloadConfigOneShot();
                        assert(false,'AutoStart type must be set.');
                end
            else
                obj.cfgLoadConfig(fname);
            end
        end
        
        function fastCfgClearConfigFile(obj,idx)
            %Clear CFG file settings cached at a numbered FastCFG
            validateattributes(idx,{'numeric'},{'scalar' 'nonnegative' 'integer' '<=' obj.FAST_CFG_NUM_CONFIGS});
            obj.fastCfgCfgFilenames{idx} = '';
        end
        
        function set.fastCfgCfgFilenames(obj,val)
            obj.zprvAssertIdle('fastCfgCfgFilenames');
            obj.validatePropArg('fastCfgCfgFilenames',val);
            obj.fastCfgCfgFilenames = val;
        end
        
        function set.fastCfgAutoStartTf(obj,val)
            obj.zprvAssertIdle('fastCfgAutoStartTf');
            obj.validatePropArg('fastCfgAutoStartTf',val);
            obj.fastCfgAutoStartTf = val;
            tfEmptyType = cellfun(@isempty,obj.fastCfgAutoStartType);
            tfAutoStartOnButEmptyType = val & tfEmptyType;
            obj.fastCfgAutoStartType(tfAutoStartOnButEmptyType) = {'grab'}; % default to grab
        end
        
        function set.fastCfgAutoStartType(obj,val)
            obj.zprvAssertIdle('fastCfgAutoStartType');
            
            obj.validatePropArg('fastCfgAutoStartType',val);
            obj.fastCfgAutoStartType = val;
        end
    end % end methods section for usr/cfg/fastcfg
    
    %% USER FUNCTIONS %%
    methods
        function set.userFunctionsCfg(obj,val)
            obj.zprvAssertIdle('userFunctionsCfg');
            if isempty(val)
                val = struct('EventName',cell(0,1),'UserFcnName',[],'Arguments',[],'Enable',[]);
            end
            
            % Validate the new value
            obj.zprpUserFunctionValidate(val,'EventName',obj.USER_FUNCTIONS_EVENTS);
            
            % Adjust listeners
            obj.zprvUserFunctionsConfigureListeners('userFunctionsCfgListeners',val);
            
            obj.userFunctionsCfg = val;
        end
        
        function set.userFunctionsUsr(obj,val)
            obj.zprvAssertIdle('userFunctionsUsr');
            if isempty(val)
                val = struct('EventName',cell(0,1),'UserFcnName',[],'Arguments',[],'Enable',[]);
            end
            
            % Validate new value
            allEvents = [obj.USER_FUNCTIONS_EVENTS;obj.USER_FUNCTIONS_USR_ONLY_EVENTS];
            obj.zprpUserFunctionValidate(val,'EventName',allEvents);
            
            % Adjust listeners
            obj.zprvUserFunctionsConfigureListeners('userFunctionsUsrListeners',val);
            
            obj.userFunctionsUsr = val;
        end
        
        function set.userFunctionsOverride(obj,val)
            obj.zprvAssertIdle('userFunctionsOverride');
            if isempty(val)
                val = struct('Function',cell(0,1),'UserFcnName',[],'Enable',[]);
            end
            obj.zprpUserFunctionValidate(val,'Function',obj.USER_FUNCTIONS_OVERRIDE_FUNCTIONS,false);
            
            % Set up userFunctionsOverriddenFcns2UserFcns
            fcnMap = struct();
            for c = 1:numel(val)
                s = val(c);
                if s.Enable
                    assert(~isfield(fcnMap,s.Function),...
                        'Function ''%s'' is overridden more than once.',s.Function);
                    fcnMap.(s.Function) = s.UserFcnName;
                end
            end
            obj.userFunctionsOverriddenFcns2UserFcns = fcnMap;
            
            obj.userFunctionsOverride = val;
        end
    end  % end user-function-related public methods
    
    methods(Hidden)
        function zprpUserFunctionValidate(obj,userFcnInfo,eventFieldName,eventsList,tfArguments)
            if nargin < 5
                tfArguments = true;
            end
            
            % Check that the right struct fields are present
            expectedFields = {eventFieldName;'UserFcnName';'Enable'};
            if tfArguments
                expectedFields = [expectedFields;'Arguments'];
            end
            if ~isstruct(userFcnInfo) || ...
                    ~isequal(sort(fieldnames(userFcnInfo)),sort(expectedFields))
                errStr = sprintf('''%s'', ',expectedFields{:});
                errStr = errStr(1:end-2);
                error('SI5:invalidUserFcnFields',...
                    'Expected value to be a struct with fields %s.',errStr);
            end
            
            % All events must be in the eventsList
            evts = {userFcnInfo.(eventFieldName)}';
            assert(all(ismember(evts,eventsList)),'One or more invalid %s.',eventFieldName);
            
            % Arguments
            if tfArguments
                args = {userFcnInfo.Arguments}';
                tfArgsOk = cellfun(@(x)iscell(x)&&(isvector(x)||isequal(x,{})),args);
                if any(~tfArgsOk)
                    error('SI5:invalidUserFunctionArguments',...
                        'Arguments for a user function must be a vector cell array.');
                end
            end
            
            % Enable
            enable = {userFcnInfo.Enable}';
            tfEnableOk = cellfun(@(x)isscalar(x)&&(islogical(x)||isnumeric(x)),enable);
            assert(all(tfEnableOk),'Enable field must be a scalar logical.');
        end
        
        function zprvUserFunctionsConfigureListeners(obj,listenerProp,newUserFcnInfo)
            % Configure listeners for user functions.
            % listenerProp: property containing listeners
            % newUserFcnInfo: user function info structs
            %
            % The backend of user functions is implemented using arrays of
            % listener objects that correspond precisely (ie in a 1-1
            % manner) with the userFunction struct arrays. Whenever a
            % userFunction struct array is updated, the corresponding array
            % of listeners is updated accordingly.
            
            Nnew = numel(newUserFcnInfo);
            
            listnrs = obj.(listenerProp);
            
            if numel(listnrs) > Nnew
                % Delete all extra listeners
                for c = Nnew+1:numel(listnrs)
                    delete(listnrs{c});
                end
                listnrs = listnrs(1:Nnew);
            elseif numel(listnrs) < Nnew
                % Pad listener vector with empty array []
                listnrs{Nnew,1} = [];
            end
            assert(numel(listnrs)==Nnew);
            
            % Setup listeners
            for c = 1:Nnew
                if isempty(listnrs{c})
                    listnrs{c} = obj.addlistener(newUserFcnInfo(c).EventName,...
                        @(src,evt)obj.zprvUserFunctionsGenericCallback(newUserFcnInfo(c),src,evt));
                else
                    listnrs{c}.EventName = newUserFcnInfo(c).EventName;
                    listnrs{c}.Callback = @(src,evt)obj.zprvUserFunctionsGenericCallback(newUserFcnInfo(c),src,evt);
                end
                listnrs{c}.Enabled = logical(newUserFcnInfo(c).Enable);
            end
            
            obj.(listenerProp) = listnrs;
        end
        
        function zprvUserFunctionsGenericCallback(obj,userFcnInfo,src,evt) %#ok<MANU>
            feval(userFcnInfo.UserFcnName,src,evt,userFcnInfo.Arguments{:});
        end
    end % end user-function-related private methods
    % end methods section for user functions
    
    %% Prop-set helpers
    methods (Hidden)
        function zprpUpdateAcqChannelOffsets(obj)
            %Set the value on the FPGA to subtract the offsets.
            for i=1:obj.MAX_NUM_CHANNELS
                obj.hAcq.channelOffsets(i) = double(obj.channelsSubtractOffset(i)) * obj.channelOffsets(i);
            end
        end
        
        function val = zprpValidateChannelsArray(obj,val,propName)
            %Further validation for the channelsSave,channelsDisplay props
            
            val = unique(val);
            assert(all(val) <= obj.MAX_NUM_CHANNELS,'Only channel values from 1-%d are supported',obj.MAX_NUM_CHANNELS);
            
            %Ensure at least one channel is active for saving or display
            if isempty(val)
                switch propName
                    case 'channelsDisplay'
                        otherProp = 'channelsSave';
                    case 'channelsSave'
                        otherProp = 'channelsDisplay';
                    otherwise
                        assert(false);
                end
                
                assert(~isempty(obj.(otherProp)),'One channel must be active for saving and/or display');
            end
        end
        
        function val = zprpEnsureChannelPropSize(obj,val)
            %Ensure correct size of channel property
            
            numChans = obj.MAX_NUM_CHANNELS;
            if length(val) < numChans
                if iscell(val)
                    [val{end+1:numChans}] = deal(val{end});
                else
                    val(end+1:numChans) = val(end);
                end
            else
                val = val(1:numChans);
            end
        end
        
        function val = zprpStackComputeZStepSize(obj)
            dz = obj.stackZEndPos - obj.stackZStartPos;
            val = dz/(obj.stackNumSlices-1);
        end
        
        function val = zprpStackComputeNumSlices(obj)
            dz = obj.stackZEndPos - obj.stackZStartPos;
            if dz==0 && obj.stackZStepSize==0
                % edge case
                val = 1;
            else
                val = floor(dz/obj.stackZStepSize)+1;
            end
        end
        
        %% Frame Decimation
        function zprpUpdateFrameAcqFcnDecimationFactor(obj)
            if isnan(obj.scanFrameRate_)
                %Use nominal scanner frequency
                isBidi = isequal(obj.scanMode,'bidirectional');
                bidiFactor = 2^isBidi;
                scanLinePeriodNominal = obj.mdfData.nominalResScanFreq / bidiFactor;
                scanFrameRateVal = 1 / (scanLinePeriodNominal * obj.linesPerFrame);
            else
                scanFrameRateVal = obj.scanFrameRate_;
            end
            obj.frameAcqFcnDecimationFactor = ceil(scanFrameRateVal / obj.maxFrameEventRate);
        end
        
        function val = zprpApplyFAFDecFactorConstraint(obj,constrainVar,fafDecFactor)
            
            if nargin < 3
                fafDecFactor = obj.frameAcqFcnDecimationFactor;
            end
            
            switch constrainVar
                case 'loggingFramesPerFile'
                    if isinf(obj.loggingFramesPerFile)
                        val = inf;
                    else
                        val = round(obj.loggingFramesPerFile / fafDecFactor) * fafDecFactor;
                    end
                case 'displayFrameBatchFactor'
                    val = ceil(obj.displayFrameBatchFactor / fafDecFactor) * fafDecFactor;
                case 'displayFrameBatchSelection'
                    val = unique(ceil(obj.displayFrameBatchSelection ./ fafDecFactor) .* fafDecFactor);
                case 'stackNumSlices'
                    if obj.fastZEnable
                        val = ceil(obj.stackNumSlices / fafDecFactor) * fafDecFactor;
                    else
                        val = obj.stackNumSlices;
                    end
                    constrainVar = 'stackNumSlices';
                case 'acqNumFrames'
                    if ~obj.fastZEnable;
                        val = ceil(obj.acqNumFrames / fafDecFactor) * fafDecFactor;
                    else
                        val = obj.acqNumFrames;
                    end
                    constrainVar = 'acqNumFrames';
                otherwise
                    assert(false);
            end
            
            %Update constrained property if output argument not returned
            if nargout == 0
                obj.(constrainVar) = val;
            end
        end
        
        function val = zprpLockDisplayRollAvgFactor(obj)
            %Identify (and apply or return) constrained displayRollingAverageFactor value - must be an integer multiple of frameAcqFcnDecimationFactor
            
            val = obj.displayRollingAverageFactor;
            
            constrainedRollAvgFactor = (obj.acqNumAveragedFrames / obj.frameAcqFcnDecimationFactor);
            if val ~= constrainedRollAvgFactor
                if constrainedRollAvgFactor == round(constrainedRollAvgFactor)
                    val = constrainedRollAvgFactor;
                else
                    val = 1;
                end
            end
            
            if nargout == 0
                obj.displayRollingAverageFactor = val;
            end
            
        end
        
        %% Acquisition and Scan Parameters
        function zprpSetAcqAndScanParameters(obj, val)
            %Set values in hScan & hAcq objects.
            obj.zprvAssertFocusOrIdle();
            
            % in acquisition mode focus a change of linesPerFrame should
            % stop the acquisition, change the parameter and restart
            rearmFocus = false;
            if strcmp(obj.acqState,'focus')
                obj.abort();
                rearmFocus = true;
            end
            
            %Compute/set line-per-frame values
            obj.hAcq.bidirectional = obj.bidirectionalAcq;
            obj.hAcq.pixelsPerLine = obj.pixelsPerLine;
            obj.hAcq.linesPerFrame =  obj.linesPerFrame;
            obj.hAcq.flybackLinesPerFrame = obj.flybackLinesPerFrame;
            obj.hAcq.fillFraction = obj.fillFraction;
            obj.hScan.periodsPerFrame = obj.linesPerFrame / 2^(obj.bidirectionalAcq);
            obj.hScan.galvoFlyBackPeriods = obj.flybackLinesPerFrame / 2^(obj.bidirectionalAcq);
            obj.hScan.zoomFactor = obj.zoomFactor;
            
            obj.hBeams.linesPerFrame = obj.linesPerFrame;
            
            if rearmFocus
                obj.startFocus();
            end
        end
        
        function zprpUpdateChanLUT(obj,chanIdx,newVal)
            set(obj.hAxes{chanIdx},'CLim',newVal);
        end
        
        function zprpUpdateLoggingFullFileName(obj)
            if isempty(obj.loggingFilePath) || isempty(obj.loggingFileStem)
                obj.hAcq.loggingFullFileName = '';
            else
                fname = obj.loggingFileStem;
                
                %Append file counters to stem
                %fname = [fname '_' sprintf('%03d',obj.loggingFileCounter)];
                %Let the C side handle numbering.
                
                %Construct full name
                obj.hAcq.loggingFullFileName = fullfile(obj.loggingFilePath,fname);
                obj.hAcq.loggingFileCounter = obj.loggingFileCounter;
            end
        end
        
        function zprpSetPixelationProp(obj,propName,val)
            pplOld = obj.pixelsPerLine;
            lpfOld = obj.linesPerFrame;
            
            pplNew = pplOld;
            lpfNew = lpfOld;
            [changePPL,changeLPF,changeSAM] = deal(false);
            
            switch propName
                case 'pixelsPerLine'
                    %We are changing pixelsPerLine.
                    pplNew = val;
                    
                    if pplNew ~= pplOld
                        changePPL = true;
                        if obj.scanForceSquarePixelation_
                            lpfNew = val;
                            changeLPF = true;
                        end
                    end
                case 'linesPerFrame'
                    %We are changing linesPerFrame.
                    lpfNew = val;
                    
                    if lpfNew ~= lpfOld
                        changeLPF = true;
                        if obj.scanForceSquarePixelation_
                            pplNew = val;
                            changePPL = true;
                        end
                    end
                case 'scanAngleMultiplier'
                    %We are changing scanAngleMultiplier.
                    changeSAM = true;
                otherwise
                    assert(false);
            end
            
            %SI5 allows for tall frames
            %The following is old SI4.2 logic
            %if obj.scanAngleMultiplierSlow > 0
            %    assert(pplNew >= lpfNew,'linesPerFrame > pixelsPerLine is not allowed at this time, except for line-scanning');
            %end
            
            if ~any([changePPL changeLPF changeSAM])
                return;
            end
            
            %obj.zprvPauseFocus(); %Stops LSM processing
            if ~changeSAM
                %Only perform the following if we are not doing a Scan
                %Angle Multiplier change only.
                obj.scanSetPixelationPropFlag = true;
                
                obj.pixelsPerLine = pplNew;
                obj.linesPerFrame = lpfNew;
                
                obj.scanSetPixelationPropFlag = false;
            end
            %Set scanAngleMultiplierSlow. This has several side-effects:
            % 1. Calls zprvUpdateChannelDisplayRatioAndLims()
            % 2. Updates Y galvo output waveform, if needed
            % 3. Calls zprvResumeFocus()
            
            if obj.scanForceSquarePixel_
                obj.scanAngleMultiplierSlow = sign(obj.scanAngleMultiplierSlow) * (obj.linesPerFrame/obj.pixelsPerLine);
            else
                obj.scanAngleMultiplierSlow = obj.scanAngleMultiplierSlow;
            end
            
            obj.zprvResetBuffersIfFocusing(); %Clears acqFrameBuffer & displayRollingBuffer
            obj.zprvResetDisplayFigs(obj.channelsDisplay,obj.channelsMergeEnable);
            %obj.zprpUpdateScanPhaseFine(); %Updates scanPhaseFine value, if needed (it can depend on pixelsPerLine)
            %disp('TODO: zprpSetPixelationProp(obj,propName,val) zprpUpdateScanPhaseFine??');
        end
    end
    
    %% IMAGE TOOLS METHODS
    methods
        function h = imageHistogram(obj,chanIdx)
            %Compute & display histogram of pixel values for last displayed image acquired at specified chanIdx
            
            validateattributes(chanIdx,{'numeric'},...
                {'scalar' 'integer' 'positive'}); % Modified to allow for merge figure selection.
            %                {'scalar' 'integer' 'positive' '<=' obj.MAX_NUM_CHANNELS});
            
            data = obj.zprvChannelDataCurrentDisplay(chanIdx);
            
            if ismember(chanIdx,obj.hMergeFigs)
                windowTitleString = 'Channel Merge Pixel Histogram';
            else
                windowTitleString = sprintf('Channel %d Pixel Histogram',chanIdx);
            end
            
            h = figure('DoubleBuffer','on','color','w','NumberTitle','off','Name',windowTitleString,...
                'PaperPositionMode','auto','PaperOrientation','landscape', 'HandleVisibility', 'callback');
            
            hist(double(data(:)),256);
            set(get(gca,'XLabel'),'String','Pixel Intensity','FontWeight','bold','FontSize',12);
            set(get(gca,'YLabel'),'String','Number of Pixels','FontWeight','bold','FontSize',12);
        end
        
        function s = imageStats(obj,chanIdx)
            %Compute & display statistics of pixel values for last displayed image acquired at specified chanIdx
            
            validateattributes(chanIdx,{'numeric'},...
                {'scalar' 'integer' 'positive'}); % Modified to allow for merge figure selection.
            %                {'scalar' 'integer' 'positive' '<=' obj.MAX_NUM_CHANNELS});
            
            data = obj.zprvChannelDataCurrentDisplay(chanIdx);
            
            s.mean = mean(data(:));
            s.std = double(std(single(data(:)))); % AL: this double(single(...)) thing is historic. why?
            s.max = max(data(:));
            s.min = min(data(:));
            s.pixels = numel(data);
            
            if nargout == 0
                ImageStats = s;
                assignin('base','ImageStats',ImageStats);
                evalin('base','ImageStats');
            end
        end
    end
    
    %Trigger update methods
    methods (Hidden)
        function applyTriggerRouting(obj)
            % first reset all existing routes
            obj.hTriggerMatrix.acqTriggerIn = '';
            obj.hTriggerMatrix.nextFileMarkerIn = '';
            obj.hTriggerMatrix.acqInterruptTriggerIn = '';
            
            obj.hTriggerMatrix.acqTriggerOnFallingEdge = false;
            obj.hTriggerMatrix.nextFileMarkerOnFallingEdge = false;
            obj.hTriggerMatrix.acqInterruptTriggerOnFallingEdge = false;
            
            types = obj.triggerExternalTypes;
            edges = obj.triggerExternalEdges;
            
            % parse the table and set up the new routes
            if obj.triggerTypeExternal
                %parse triggers types
                for rowindex = 1:numel(types)
                    typeName = types{rowindex};
                    triggerTerminal = obj.triggerExternalTerminals{rowindex};                    
                    
                    fallingEdge = strcmp(edges{rowindex},'falling');
                    switch typeName
                        case 'Acquisition Start'
                            obj.hTriggerMatrix.acqTriggerIn = triggerTerminal;
                            obj.hTriggerMatrix.acqTriggerOnFallingEdge = fallingEdge;
                        case 'Acquisition Stop'
                            obj.hTriggerMatrix.acqInterruptTriggerIn = triggerTerminal;
                            obj.hTriggerMatrix.acqInterruptTriggerOnFallingEdge = fallingEdge;
                        case 'Next File Marker'
                            obj.hTriggerMatrix.nextFileMarkerIn = triggerTerminal;
                            obj.hTriggerMatrix.nextFileMarkerOnFallingEdge = fallingEdge;
                        otherwise
                            assert(false);
                    end
                    
                end
            end
        end
        
        function updateStaticTriggerRouting(obj)
            %set up the period clock input terminal
            if obj.digitalIODeviceIsFPGA
                periodTriggerInDev = obj.hScan.mdfData.scanCtrlDeviceName;
                fprintf('Digital IO device is an FPGA. Using scan control daq board for period clock input.\n');
            else
                periodTriggerInDev = obj.mdfData.digitalIODeviceName;
            end
            periodTriggerTerm = sprintf('/%s/%s',periodTriggerInDev,'PFI0');
            fprintf('Connecting period clock input to %s\n',periodTriggerTerm);
            obj.hTriggerMatrix.periodClockIn = periodTriggerTerm;
            
            %set up all other routes
            if obj.digitalIODeviceIsFPGA
                staticRoutes = obj.STATIC_TRIGGER_MAP_FPGA;
            else
                staticRoutes = obj.STATIC_TRIGGER_MAP_DAQ;
            end
            
            for i = 1:size(staticRoutes,1)
                triggerName = staticRoutes{i,1};
                triggerTerminal = staticRoutes{i,2};
                obj.hTriggerMatrix.(triggerName) = triggerTerminal;
            end
        end
    end
    
    %% ABSTRACT PROP REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclInitPropAttributes();
        mdlHeaderExcludeProps = {'hMotors' 'hFastZ' 'hBeams' 'hAcq' 'hScan' 'hTriggerMatrix' 'acqFrameBuffer' 'acqFrameNumberBuffer' 'usrPropListCurrent'}; %'hPlugins'
        mdlInitSetExcludeProps = {'motorPosition'};
    end
end

%% LOCAL FUNCTIONS
function val = zlclEncodeTriggerEdge(edge)
switch lower(edge)
    case 'rising'
        val = 'DAQmx_Val_Rising';
    case 'falling'
        val = 'DAQmx_Val_Falling';
end
end

function evs = zlclInitUserFunctionsEvents()
mc = ?scanimage.SI5;
allEvents = mc.Events;
tf = cellfun(@(x)isequal(x.DefiningClass,mc)&&strcmp(x.NotifyAccess,'protected'),allEvents);
evs = allEvents(tf);
evs = cellfun(@(x)x.Name,evs,'UniformOutput',false);
end

function evs = zlclInitUserFunctionsUsrOnlyEvents()
mc = ?scanimage.SI5;
allEvents = mc.Events;
tf = cellfun(@(x)isequal(x.DefiningClass,mc)&&strcmp(x.NotifyAccess,'private'),allEvents);
evs = allEvents(tf);
evs = cellfun(@(x)x.Name,evs,'UniformOutput',false);
end

function x = zlclVerifyScalarIntegerOrInf(x)
assert(isscalar(x)&&isnumeric(x)&&(most.idioms.isIntegerValued(x)||isinf(x)),...
    'Expected scalar integer or inf.');
end

function s = zlclInitPropAttributes()
%At moment, only application props, not pass-through props, stored here -- we think this is a general rule
%NOTE: These properties are /ordered/..there may even be cases where a property is added here for purpose of ordering, without having /any/ metadata.
%       Properties are initialized/loaded in specified order.
%
s = struct();
s.focusDuration = struct('Range',[1 inf]);

%% Acquisition
s.acqNumFramesPerTrigger = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.acqsPerLoop = struct('Attributes',{{'scalar' 'nonnegative'}});
s.loopAcqCounter = struct('Attributes',{{'scalar' 'nonnegative' 'finite' 'integer'}});
s.acqBeamOverScan = struct('Attributes',{{'scalar' 'finite'}});

s.scanFrameRate_ = struct('DependsOn',{{'resonantScannerFreq' 'bidirectionalAcq' 'linesPerFrame' 'flybackLinesPerFrame'}});
s.scanFramePeriod = struct('DependsOn',{{'scanFrameRate_'}});
s.linePeriod_ = struct('DependsOn',{{'resonantScannerFreq'}});
s.fillFraction = struct('Range',[0 1], 'Attributes','scalar');
s.fillFractionTime = struct('Attributes',{{'scalar' 'positive' 'finite'}});
s.bidirectionalAcq = struct('Classes','binaryflex','Attributes','scalar');
s.flybackLinesPerFrame = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.zoomFactor = struct('Attributes',{{'scalar' 'positive' 'finite'}});
s.numFrames = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.frameCounter = struct('Attributes',{{'scalar' 'nonnegative' 'finite' 'integer'}});
s.multiChannel = struct('Classes','binarylogical','Attributes','scalar');

s.chan1LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan2LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan3LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan4LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.loopAcqInterval = struct('Attributes',{{'scalar','positive','integer','finite'}});

%% logging
s.loggingDir = struct('Classes','string','AllowEmpty',1);
s.loggingFileStem = struct('Classes','string','AllowEmpty',1);
s.loggingFileCounter = struct('Attributes',{{'scalar' 'positive' 'finite'}});
s.loggingEnable = struct('Classes','binarylogical','Attributes','scalar');
s.loggingFramesPerFile = struct('Attributes',{{'positive' 'integer'}},'CustomValidateFcn',@zlclVerifyScalarIntegerOrInf);
s.loggingFramesPerFileLock = struct('Classes','binaryflex','Attributes','scalar');

%% usr/cfg/fastcfg
s.fastCfgCfgFilenames = struct('Classes','char','List',scanimage.SI5.FAST_CFG_NUM_CONFIGS,'AllowEmpty',1);
s.fastCfgAutoStartTf = struct('Classes','binaryflex','Attributes',{{'size',[scanimage.SI5.FAST_CFG_NUM_CONFIGS 1]}});
s.fastCfgAutoStartType = struct('Options',{{'focus';'grab';'loop'}},'List',scanimage.SI5.FAST_CFG_NUM_CONFIGS,'AllowEmpty',true);

%% Trigger structs
s.triggerTypeExternal = struct('Classes','binarylogical','Attributes','scalar');
s.triggerExternalTerminals = struct('Classes','cell','Options','triggerExternalTerminalOptions');
s.triggerExternalTypes = struct('Classes','cell');
s.triggerExternalEdges = struct('Classes','cell');

%% Stack structs
s.stackNumSlices = struct('Attributes',{{'positive' 'integer' 'finite'}});
s.stackZStepSize = struct('Attributes','scalar');
s.stackZStartPos = struct('Attributes','scalar');
s.stackZEndPos = struct('Attributes','scalar');
s.stackUseStartPower = struct('Classes','binaryflex','Attributes','scalar');
s.stackUserOverrideLz = struct('Classes','binaryflex','Attributes','scalar');
s.stackReturnHome = struct('Classes','binaryflex','Attributes','scalar');
s.stackStartCentered = struct('Classes','binaryflex','Attributes','scalar');

s.periodClockPhase = struct('Attributes',{{'finite','integer','scalar'}});
%% Shutter structs
s.shutterDelay = struct('Attributes',{{'nonnegative' 'scalar' 'finite'}});

%% FastZ structs
s.fastZImageType = struct('Options',{{'XY-Z' 'XZ' 'XZ-Y'}});
s.fastZScanType = struct('Options', {{'step' 'sawtooth'}});
s.fastZSettlingTime = struct('Attributes','nonnegative');
s.fastZPeriod = struct('Attributes', 'nonnegative');
s.fastZNumVolumes = struct('Attributes',{{'positive' 'integer' 'finite'}});
s.fastZUseAOControl = struct('Classes','binaryflex','Attributes','scalar');
s.fastZFramePeriodAdjustment = struct('Range',[-5000 5000]);
s.fastZNumDiscardFrames = struct('DependsOn',{{'fastZNumVolumes' 'acqNumFramesPerTrigger' 'stackNumSlices' 'fastZAcquisitionDelay' 'fastZSettlingTime' 'scanFrameRate_' 'fastZDiscardFlybackFrames'}});
s.fastZEnable = struct('Classes','binaryflex','Attributes','scalar');
s.fastZAllowLiveBeamAdjust = struct('Classes','binaryflex','Attributes','scalar');

%% Channel structs
s.channelsDisplay = struct('Classes','numeric','Attributes',{{'vector','integer'}},'AllowEmpty',1);
s.channelsSave = struct('Classes','numeric','Attributes',{{'vector','integer'}},'AllowEmpty',1);
s.channelsMergeColor = struct('Options',{{'green' 'red' 'blue' 'gray' 'none'}},'List','fullVector');
s.channelsMergeEnable = struct('Classes','binaryflex','Attributes','scalar');
s.channelsMergeFocusOnly = struct('Classes','binaryflex','Attributes','scalar');
s.channelsInputRange = struct('Options','channelsInputRangeValues','List','fullVector');
s.channelsSubtractOffset = struct('Classes','binaryflex','Attributes','vector','AllowEmpty',1);
s.channelsAutoReadOffsets = struct('Classes','binaryflex','Attributes','scalar');

%% Display structs
s.acqDebug = struct('Classes','binaryflex','Attributes','scalar');
s.acqNumFrames = struct('Attributes',{{'positive' 'integer'}});
s.acqNumAveragedFrames = struct('Attributes',{{'positive' 'integer' 'finite'}});
s.acqFrameBufferLengthMin = struct('Attributes',{{'integer' 'nonnegative' 'finite'}});

s.displayFrameBatchFactorLock = struct('Classes','binaryflex','Attributes','scalar');
s.displayFrameBatchSelectLast = struct('Classes','binaryflex','Attributes','scalar');
s.displayRollingAverageFactorLock = struct('Classes','binaryflex','Attributes','scalar');
s.displayRollingAverageFactor = struct('Attributes',{{'positive' 'integer' 'finite'}});
s.displayFrameBatchFactor = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar'}});
s.displayFrameBatchSelection = struct('Attributes',{{'vector' 'positive' 'integer' 'finite'}});
s.displayShowCrosshair = struct('Classes','binaryflex','Attributes','scalar');

%% Beam structs
s.beamPowersDisplay = struct('Attributes',{{'nonnegative' 'finite' 'vector'}},'AllowEmpty',1);
s.beamPowerLimits = struct('Attributes',{{'nonnegative' 'finite' 'vector'}},'AllowEmpty',1);
s.beamFlybackBlanking = struct('Classes','binaryflex');
s.beamDirectMode = struct('Classes','binaryflex','Attributes','scalar');
s.beamPowerUnits = struct('Options',{{'percent' 'milliwatts'}});
s.beamLengthConstants = struct('Attributes',{{'positive' 'vector'}},'AllowEmpty',1);
s.beamPzAdjust = struct('Classes','binarylogical','Attributes','scalar');

%% Configuration structs
s.scanPixelTimeStats = struct('DependsOn',{{'fillFraction','pixelsPerLine'}});
s.scanPixelTimeMean = struct('DependsOn','scanPixelTimeStats');
s.scanPixelTimeMaxMinRatio = struct('DependsOn','scanPixelTimeStats');
s.scanForceSquarePixelation = struct('Classes','binaryflex');
s.scanForceSquarePixel = struct('Classes','binaryflex');
s.scanForceSquarePixelation_ = struct('DependsOn',{{'scanForceSquarePixelation'}}); %'scanAngleMultiplierSlow'}});
s.scanForceSquarePixel_ = struct('DependsOn',{{'scanForceSquarePixel'}}); % 'scanAngleMultiplierSlow'}});
s.scanShiftSlow = struct('Attributes',{{'scalar' 'finite'}});
s.scanAngleMultiplierSlow = struct('Attributes',{{'finite' 'scalar'}},'Range',[-1 1]);

%% Bscope2 structs
s.bscope2ScanAlign = struct('Attributes',{{'scalar','integer','finite'}},'Range',[0 255]);

%%
s.linesPerFrame = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.pixelsPerLine = struct('Attributes','scalar','Options',2.^(4:11)');

end


%--------------------------------------------------------------------------%
% SI5.m                                                                    %
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
