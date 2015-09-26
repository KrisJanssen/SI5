classdef ResonantAcq < most.MachineDataFile
    %RESONANTACQ
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)    
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ResonantAcq';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %% PUBLIC PROPERTIES
    
    % Settable during an active acquisition
    properties                
        singleChannelNumber = 1;    % channel to be displayed in single channel mode
        periodClockPhase = 0;       % in ticks
        reverseLineRead = false;    % flip the image horizontally
        beamOverScan = [0 0];       % in microseconds; a vector of 2 elements: [BeamOnLead,BeamOffLag]
        channelsInputRanges = {[-1,1],[-1,1],[-1,1],[-1,1]}; % input ranges for all channels
        channelsFilterType = 'Bypass'; % one of {'Bypass', 'Elliptic', 'Bessel'}
        channelOffsets = [0 0 0 0]; % channel offsets for all channels. Don't change default values of [0 0 0 0]
        channelsInvert = false;     % specifies if the digitizer inverts the channel values
    end
    
    properties (Dependent)
       rawAdcOutput;                % returns up-to-date Adc data without processing. can be queried at any time
       dataRate;                    % the theoretical dataRate produced by the acquisition in MB/s
       dcOvervoltage;               % true if input voltage range is exceeded. indicates that coupling changed to AC to protect ADC
       channelsCoupling;            % one of {'DC','AC'}; setting this property resets dcOvervoltage condition
       shutterOutput;               % logical, determines the output state of the shutter terminal
       shutterOut;                  % Output terminal for the shutter one of {'', 'DIO1.0'..'DIO1.3', 'PXI_Trig0'..'PXI_Trig7'}
    end
    
    properties                
        pixelsPerLine = 512;        % Horizontal frame size
        linesPerFrame = 512;        % Vertical frame size
        flybackLinesPerFrame = 2;   % Number of lines to allow the Y-galvo to fly back. Must be even for a bidirectional scan
        bidirectional = true;       % Specifies if the both sweep directions of the resonant scanner produce a line
        fillFraction = 0.8;
        simulatedFramePeriod = 33;  % Frame Period (in ms) at which to issue frames in simulated mode.
        displayDecimationFactor = 1;% Decimation factor for frames sent to MATLAB.
        displayBatchingFactor = 1;  % Batching factor for frames sent to MATLAB.
        
        framesPerStack = 1;         % number of slices in a stack. Designed originally to make FPGA aware of fastZ volumes.
        framesPerAcquisition = 10;  % Number of frames to be acquired after the Acquisition Trigger. (0 = infinite)
        acquisitionsPerAcquisitionMode = 10;   % Number of acquisitiosn before acquisition mode  stops (0 = infinite)
        
        scannerFrequency = 7910;    % Frequency of the resonant scanner in Hz
        
        multiChannel = true;        % Channels to acquire
        frameTagging = true;        % Activates frame tagging (now always active - 4/21/14)
        
        frameAcquiredFcn;           % Callback function to be executed when a frame is acquired
        
        debugOutput = false;
        dummyData = false;

        %Logging internal properties
        loggingAverageFactor = 1;
        loggingEnable = false;
        loggingSlowStack = false;
        loggingNumSlowStackSlices = 0;
        loggingFullFileName;
        loggingFileCounter;
        loggingOpenModeString = 'wbn';
        loggingHeaderString;
        loggingFramesPerFile;
        loggingFramesPerFileLock;
        loggingChannelsArray = [];      % 1xN array of channel numbers to log. If the channel is not located here, it is not logged.
        numLoggingChannels;
        
        acqTriggerIn = '';              % Input terminal of Acquisition Start Trigger. Valid Values are one of {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
        periodClockIn = '';             % Input terminal of the Resonant Scanner Sync signal. Valid Values are one of {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
        nextFileMarkerIn = '';          % Input terminal of Next File Trigger. Valid Values are {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
        acqInterruptTriggerIn = '';     % Input terminal of Acquisiton Interrupt Trigger. Valid Values are {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
        frameClockOut = '';             % Output terminal for the Frame Clock generated on the FPGA. Valid Values are {'', 'DIO1.0'..'DIO1.3', 'PXI_Trig0'..'PXI_Trig7'}
        beamModifiedLineClockOut = '';  % Output terminal for the Beam Clock generated on the FPGA. Valid Values are {'', 'DIO1.0'..'DIO1.3', 'PXI_Trig0'..'PXI_Trig7'}
        acqTriggerOut = '';             % Output terminal for the Acquisition Trigger. Can be used to export a software trigger {'', 'DIO1.0'..'DIO1.3', 'PXI_Trig0'..'PXI_Trig7'}        
        
        periodClockOnFallingEdge = false;
        acqTriggerOnFallingEdge = false;
        nextFileMarkerOnFallingEdge = false;
        acqInterruptTriggerOnFallingEdge = false;
		
		acqTriggerTypeExternal = false;   % If true, the FPGA listens for the acquisition Trigger on a digital input. If false, use function generateSoftwareAcqTrigger() to start the Acquisition
        
        %simulated mode
        simulated=false;
        
        delayMaskComputation = false;
    end
       
    %Constructor-initialized properties, depend on installed hardware
    properties (SetAccess = private)
        bitDepth;
        sampleRate;
        flexRioAdapterModule;
        adapterModuleChannelCount;
    end

    properties (SetAccess = private)
        samplesPerPeriod;
        samplesPerLine;
        samplesPerLineSwitch;
        scanLineDuration; % Duration, in seconds, of the portion of the scan line within the fill fraction (computed via mask)
        framesAcquired = 0;
    end
    
    
    %% HIDDEN PROPERTIES
    
    properties (Hidden, SetAccess = private)
        mask; %Array specifies samples per pixel for each resonant scanner period
        estimatedPeriodClockDelay; % delays the start of the acquisition relative to the period trigger to compensate for line fillfraction < 1
        %frameQueueRecordSize; %Size of frame queue record (frame + optional frame tag), in bytes
        frameSizePixels;        %Number of Pixels in one frame (not including frame tag)
        frameSizeBytes;         %Number of Bytes in one frame (frame + optional frame tag)
        frameSizeFifoElements;  %Number of FIFO elements for one frame (frame + optional frame tag)
        tagSizeFifoElements;    %Number of FIFO elements for the tag (0 for frameTagging == 0)
        
        acqRunning = false;
        flagResizeAcquisition = true; % After startup the frame copier needs to be initialized
        flagUpdateMask = true;        % After startup the mask needs to be sent to the FPGA
        
        couplingSetToAC = false;
        cmdSent = false;
        
        mexInit = false;
    end
    
    properties (Dependent, Hidden)
        linesPerPeriod;
        triggerHoldOff;
        preTriggerSamples;
        periodsPerFrame;
        beamTiming;
    end
    
    properties (Hidden, SetAccess = immutable)
        hModel;
        hFpga;
        fpgaFifoNumberSingleChan;
        fpgaFifoNumberMultiChan;
    end
    
    properties (Hidden, Constant)
        ADAPTER_MODULE_MAP = containers.Map({278099318, 278099349, 278099186},{'NI5732','NI5734','NI5751'});
        ADAPTER_MODULE_CHANNEL_COUNT = containers.Map({'NI5732','NI5734','NI5751'},{2,4,4});
        ADAPTER_MODULE_SAMPLING_RATE_MAP = containers.Map({'NI5732','NI5734','NI5751'},{80e6,120e6,50e6});
        ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY = containers.Map({'NI5732','NI5734','NI5751'},{16,16,0}); % TODO: Evaluate trigger delay for NI5751
        ADAPTER_MODULE_ADC_BIT_DEPTH = containers.Map({'NI5732','NI5734','NI5751'},{14,16,14});
        CHANNEL_INPUT_RANGE_FPGA_COMMAND_DATA_MAP = containers.Map({1,0.5,0.25},{0,1,2});
        
        FRAME_TAG_SIZE_BYTES = 32;
        FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN = 8;
        FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN = 2;
        TRIGGER_HEAD_PROPERTIES = {'triggerClockTimeFirst' 'triggerTime' 'triggerFrameStartTime' 'triggerFrameNumber'};
        CHANNELS_INPUT_RANGES = {[-1 1] [-.5 .5] [-.25 .25]};
        
        HW_DETECT_POLLING_INTERVAL = 0.1;   %Hardware detection polling interval time (in seconds)
        HW_DETECT_TIMEOUT = 5;              %Hardware detection timeout (in seconds)
        HW_POLLING_INTERVAL = 0.01;         %Hardware polling interval time (in seconds)
        HW_TIMEOUT = 0.5;                   %Hardware timeout (in seconds)
        
        fifoSizeFrames = 16;
        frameQueueCapacity = 16;
    end
    
    %% Lifecycle
    methods
        function obj = ResonantAcq(hModel)
            if isempty(hModel) || ~isvalid(hModel)
                hModel = [];
            end
            
            obj.hModel = hModel;
            
            if ~isempty(obj.hModel)
                obj.simulated = obj.hModel.mdfData.simulated;
            end
            
            obj.dispDbgMsg('Initializing Object & Opening FPGA session');
            
            % Determine bitfile name
            if isfield(obj.mdfData, 'pathToBitfile')
                pathToBitfile = [fileparts(which('scanimage5.m')) '\SI5 LabVIEW FPGA\FPGA Bitfiles\' obj.mdfData.pathToBitfile];
                assert(logical(exist(pathToBitfile, 'file')), 'The specified bitfile was not found.');
            else
                pathToBitfile = [fileparts(which('scanimage5.m')) '\SI5 LabVIEW FPGA\FPGA Bitfiles\Microscopy'];
                
                if ~isempty(obj.mdfData.fpgaModuleType)
                    pathToBitfile = [pathToBitfile ' ' obj.mdfData.fpgaModuleType];
                end
                
                if ~isempty(obj.mdfData.digitizerModuleType)
                    pathToBitfile = [pathToBitfile ' ' obj.mdfData.digitizerModuleType];
                end
                
                pathToBitfile = [pathToBitfile '.lvbitx'];
                assert(logical(exist(pathToBitfile, 'file')), 'The FPGA and digitizer combination specified in the machine data file is not currently supported.');
            end
            
            obj.hFpga = dabs.ni.rio.NiFPGA(pathToBitfile,obj.simulated);

            if (~obj.simulated)
                try
                    obj.hFpga.openSession(obj.mdfData.rioDeviceID);
                catch ME
                    error('Scanimage5:ResonantAcq',['Failed to start FPGA. Ensure the FPGA and digitizer module settings in the machine data file match the hardware.\n' ME.message]);
                end
            end
            
            assert(isprop(obj.hFpga,'fifo_SingleChannelToHostI16') ...
                    && isprop(obj.hFpga,'fifo_MultiChannelToHostU64'),...
                'Expected FIFO objects not found for loaded FPGA module bitfile');
            
            %Hard-Reset FPGA. This brings the FPGA in a known state after an aborted acquisition
            obj.fpgaReset();
            
            if (~obj.simulated)
                obj.fpgaDetectAdapterModule();
            else
                % fake it
                obj.bitDepth=16;
                obj.sampleRate=80e6;
                obj.flexRioAdapterModule = 'NI5734';
                obj.adapterModuleChannelCount = 0;
            end

            %Store FPGA device FIFO names. The names of the FIFO are parsed
            %from the bitfile, so they can change when the FPGA code is
            %modified. Storing the parameters here enables us to change the
            %names in Matlab without having to recompile the MEXfunction
            obj.fpgaFifoNumberSingleChan = obj.hFpga.fifo_SingleChannelToHostI16.fifoNumber;
            obj.fpgaFifoNumberMultiChan = obj.hFpga.fifo_MultiChannelToHostU64.fifoNumber;          
            
            %Initialize MEX-layer interface
            obj.mexInit = true;
            ResonantAcqMex(obj,'init');

            %Initialize Mask
            obj.zzzComputeMask();
            
            %Set basic channel properties
            obj.channelsFilterType = 'Bessel';
            obj.channelsInvert = obj.mdfData.channelsInvert;
        end
        
        function delete(obj)
            if obj.acqRunning
                obj.abort();
            end
            
            if obj.mexInit
                ResonantAcqMex(obj,'delete');
            end
            clear ResonantAcqMex; % unload mex file
            
            most.idioms.safeDeleteObj(obj.hFpga);
        end
    end
    
    
    %% Public Methods
    methods
        
        function start(obj)
            obj.dispDbgMsg('Starting Acquisition');

            if ~obj.simulated
                obj.fpgaCheckAdapterModuleInitialization();
            end

            if obj.dataRate > 240
                fprintf(2,'The current acquisition data rate is %.2f MB/s, while the bandwith of PCIe v1.x is 250MB/s. This might result in data loss.\n',obj.dataRate);
            end
            
            if ~obj.simulated
                if ~obj.couplingSetToAC && obj.dcOvervoltage
                    disp('Recovering from DC overvoltage condition');
                    obj.channelsCoupling = 'DC';
                end
            end
            
            obj.hFpga.AcqEngineDoReset = true;
            obj.fpgaUpdateAcquisitionParameters();
            
            obj.delayMaskComputation = false;
            if obj.flagUpdateMask
                obj.zprpUpdateMask();
            end

            obj.fpgaSelectFifo();
            
            % reset frame counter
            obj.framesAcquired = 0;
            
            %force resize on start (we don't know why, but it fixes shift issue in image)
            if true || obj.flagResizeAcquisition
                obj.zprpResizeAcquisition();
            end
            
            %Start acquisition 
            ResonantAcqMex(obj,'startAcq');     % Arm Frame Copier to receive frames
            obj.hFpga.AcqEngineDoArm = true;    % then start the acquisition
            obj.acqRunning = true;
        end
        
        function abort(obj)
            if ~obj.acqRunning
                return
            end
         
            ResonantAcqMex(obj,'stopAcq');

            obj.hFpga.AcqEngineDoReset = true;            

            if (~obj.simulated)
                obj.fpgaStopFifo();
            end
            
            obj.acqRunning = false;
        end
		
		function generateSoftwareAcqTrigger(obj)
            %Temporarily store value of triggerTypeExternal.
            tempTriggerTypeExternal = obj.acqTriggerTypeExternal;
            obj.acqTriggerTypeExternal = false;
            
            obj.hFpga.AcqTriggerDoSoftwareTrig = true;
            
            %Restore original condition of trigger type.
            obj.acqTriggerTypeExternal = tempTriggerTypeExternal;
        end
        
        function generateSoftwareAcqStopTrigger(obj)
            %Temporarily store value of triggerType.
            tempTriggerType = obj.hFpga.StopTriggerType;
            obj.hFpga.StopTriggerType = 'Software';
            
            obj.hFpga.StopTriggerDoSoftwareTrig = true;
            
            %Restore original condition of trigger type.
            obj.hFpga.StopTriggerType = tempTriggerType;
        end
        
        function generateSoftwareNextFileMarkerTrigger(obj)
            %Temporarily store value of triggerType.
            tempTriggerType = obj.hFpga.AdvanceTriggerType;
            obj.hFpga.AdvanceTriggerType = 'Software';
            
            obj.hFpga.AdvanceTriggerDoSoftwareTrig = true;
            
            %Restore original condition of trigger type.
            obj.hFpga.AdvanceTriggerType = tempTriggerType;
        end        
        
        function [frame, tag, flags, elremaining, FramesRemaining] = readFrame(obj)           
            assert(obj.acqRunning,'Acquisition is not running');
            
            persistent dcOvervoltageWarningIssued;
            if obj.framesAcquired == 0
               dcOvervoltageWarningIssued = false; 
            end    
            
            [frame, tag, placeholder, elremaining, FramesRemaining] = ResonantAcqMex(obj,'getFrame');
            obj.framesAcquired = obj.framesAcquired + obj.displayDecimationFactor;
            
            flags = struct('endOfAcquisition',false,'endOfAcquisitionMode',false,'overvoltage',false);
            
            % placeholder format (uint16)
            %                            +------- DC overvoltage
            %                            | +----- end of acquisition
            %                            | | +--- end of acquisition mode
            %                            | | |
            %  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
            %  |                             |
            % msb                           lsb
            
            if bitget(uint16(placeholder),3) % DC overvoltage
                flags.overvoltage = true;
                if ~dcOvervoltageWarningIssued
                    fprintf(2,'DC Overvoltage detected - Coupling changed to AC\n');
                    dcOvervoltageWarningIssued = true;
                end
            end

            if bitget(uint16(placeholder),2) % end of acquisition
                flags.endOfAcquisition = true;
            end
            
            if bitget(uint16(placeholder),1) % end of acquisition mode
                flags.endOfAcquisitionMode = true;
                obj.abort(); %self-shutdown
            end
        end
    end
    
    %% Property Access Methods
    %Dependend Properties
    methods
        function set.shutterOutput(obj,val)
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            obj.hFpga.ShutterOutput = val;
        end
        
        function val = get.shutterOutput(obj)
            val = obj.hFpga.ShutterOutput;
        end
        
        function set.framesPerStack(obj,val)
            obj.framesPerStack = val;
            
            %Side Effects
            obj.hFpga.AcqParamFramesPerStack = val;
        end
        
        function val = get.framesPerStack(obj)
            val = obj.framesPerStack;
        end
        
        function set.shutterOut(obj,val)
            obj.hFpga.ShutterTerminalOut = val;
        end
        
        function val = get.shutterOut(obj)
           val = obj.hFpga.ShutterTerminalOut;
        end
        
        function set.channelsCoupling(obj,val)
           switch obj.flexRioAdapterModule
               case 'NI5751'
                   if strcmp(val,'DC')
                       obj.couplingSetToAC = false;
                       return
                   else
                       error('Not a valid coupling mode for adapter module NI5751: ''%s''',val);
                   end
                   
               otherwise % handle the NI573x series
                   switch val
                       case 'AC'
                           setCoupling(0);  % 0 = AC coupling nonzero = DC coupling
                           obj.couplingSetToAC = true;
                       case 'DC'
                           if obj.dcOvervoltage
                               setCoupling(0); % setting coupling mode to AC clears overvoltageStatus
                           end
                           setCoupling(1);  % 0 = AC coupling nonzero = DC coupling
                           obj.couplingSetToAC = false;
                       otherwise
                           assert(false,'Not a valid coupling mode: %s',val);
                   end
           end
           
           %Helper function
           function setCoupling(userData1)    
               for channelNumber = 0:(obj.adapterModuleChannelCount-1)
                   % Execute user command
                   userCommand = 3; % User command for coupling settings (Refer to FlexRIO help)
                   userData0 = channelNumber; %channel Number on FPGA is zero-based
                   
                   obj.sendNonBlockingAdapterModuleUserCommand(userCommand,userData0,userData1);
               end
           end
        end
        
        function val = get.channelsCoupling(obj)
            if obj.couplingSetToAC || obj.dcOvervoltage
                val = 'AC';
            else
                val = 'DC';
            end
        end
        
        function val = get.dcOvervoltage(obj)
            val = obj.hFpga.AcqStatusDCOvervoltage;
        end
        
        function val = get.dataRate(obj)
            pixelsPerRecord = obj.pixelsPerLine * 2^obj.bidirectional;
            
            if obj.multiChannel
               bytesPerRecord = pixelsPerRecord * obj.FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN;
            else
               bytesPerRecord = pixelsPerRecord * obj.FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN;
            end
            
            dataRate = bytesPerRecord * obj.scannerFrequency; % in bytes/second
            val = dataRate / 1E6;   % in MB/s
        end
                                    
        function val = get.rawAdcOutput(obj)
            obj.fpgaCheckAdapterModuleInitialization();
            val = obj.hFpga.DebugRawAdcOutput;
        end
        
        function val = get.periodsPerFrame(obj)
            val = obj.linesPerFrame / obj.linesPerPeriod;
            assert(val == floor(val),'periodsPerFrame must be an integer. Current Value: %f',val);
        end      
        
        function val = get.linesPerPeriod(obj)
            val = 2^(obj.bidirectional);
        end
        
       function value = get.triggerHoldOff(obj)
            holdOff = obj.periodClockPhase + obj.estimatedPeriodClockDelay;
            
            if holdOff > 0
                value = holdOff;
            else
                value = 0;
            end
        end
        
        function value = get.preTriggerSamples(obj)
            holdOff = obj.periodClockPhase + obj.estimatedPeriodClockDelay;
            
            if holdOff < 0
                value = abs(holdOff);
            else
                value = 0;
            end
        end

        function value = get.estimatedPeriodClockDelay(obj)
            %TODO: Improve Performance
            totalSamplesPerLine = ( obj.sampleRate / obj.scannerFrequency ) / 2;   
            maskSamplesPerLine = sum(abs(obj.mask)) / (2^obj.bidirectional);
            
            estimatedPeriodClockDelay = (totalSamplesPerLine - maskSamplesPerLine) / (2^~obj.bidirectional);
            
            estimatedPeriodClockDelay = estimatedPeriodClockDelay +...
                obj.ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY(obj.flexRioAdapterModule);
            value = round(estimatedPeriodClockDelay);
        end
        
        function value = get.beamTiming(obj)
            ticksBeamOverScan = round( ( obj.beamOverScan / 1e6 ) * obj.sampleRate );
            beamOnLeadTicks = ticksBeamOverScan(1);
            beamOffLagTicks = ticksBeamOverScan(2);
            
            beamClockOnForward   = - beamOnLeadTicks;
            beamClockOffForward  = obj.samplesPerLine + beamOffLagTicks;
            
            if obj.bidirectional
                beamClockOnBackward  = obj.samplesPerLine + obj.samplesPerLineSwitch - beamOnLeadTicks;
                beamClockOffBackward = 2 * obj.samplesPerLine + obj.samplesPerLineSwitch + beamOffLagTicks;
            else
                beamClockOnBackward  = 0;
                beamClockOffBackward = 0;
            end
            
            if beamOnLeadTicks > obj.triggerHoldOff
                fprintf(2,'Beams switch time is set to precede period clock. This setting cannot be fullfilled.\n');
            end
            
            beamTiming = [beamClockOnForward beamClockOffForward beamClockOnBackward beamClockOffBackward];
            value = beamTiming;
        end
    end
    
    %System Properties
    methods
        function set.delayMaskComputation(obj,val)
            obj.zprpAssertNotRunning('delayMaskComputation');
            statusChanged = obj.delayMaskComputation ~= val;
            obj.delayMaskComputation = val;
            
            %side effect
            if statusChanged && ~obj.delayMaskComputation
               obj.zzzComputeMask();
            end            
        end 
    end    
    
    %% Property Access Methods for Acquisition Parameters
    methods        
        function set.framesPerAcquisition(obj,val) 
            %obj.zprpAssertNotRunning('framesPerAcquisition');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'scalar','integer','nonnegative'});
            obj.framesPerAcquisition = val;
        end
        
        function set.acquisitionsPerAcquisitionMode(obj,val) 
            %obj.zprpAssertNotRunning('acquisitionsPerAcquisitionMode');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'scalar','nonnegative'});
            obj.acquisitionsPerAcquisitionMode = val;
        end
        
        function set.frameTagging(obj,val)
            %validation
            %obj.zprpAssertNotRunning('frameTagging');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.frameTagging = val;
            %side effects
            obj.flagResizeAcquisition = true;
        end
        
        function set.multiChannel(obj,val)
            %validation
            %obj.zprpAssertNotRunning('multiChannel');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.multiChannel = val;
            %side effects
            obj.flagResizeAcquisition = true;
        end
        
        function set.pixelsPerLine(obj,val)
            %validation
            %obj.zprpAssertNotRunning('pixelsPerLine');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'positive' 'scalar' 'integer'});
            %set prop
            obj.pixelsPerLine = val;
            %side effects
            obj.zzzComputeMask();
            obj.flagResizeAcquisition = true;
        end
        
        function set.linesPerFrame(obj,val)
            %validation
            %obj.zprpAssertNotRunning('linesPerFrame');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'positive' 'scalar' 'integer'});
            %set prop
            obj.linesPerFrame = val;
            %side effects
            obj.zzzComputeMask();
            obj.flagResizeAcquisition = true;
        end
        
        function set.flybackLinesPerFrame(obj,val)
            %validation
            %obj.zprpAssertNotRunning('flybackLinesPerFrame');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'nonnegative' 'scalar' 'integer'});
            %set prop
            obj.flybackLinesPerFrame = val;
        end
        
        function val = get.flybackLinesPerFrame(obj)
            %assert(mod(obj.flybackLinesPerFrame,2^obj.bidirectional) == 0,'Number of Flyback Lines must be even for bidirectional scan');  - only works with submodels, otherwise breaks MVC bindings.
            val = obj.flybackLinesPerFrame;
        end
        
        function set.fillFraction(obj,val)
            %validation
            %obj.zprpAssertNotRunning('fillFraction');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'positive' 'scalar'});
            %set prop
            obj.fillFraction = val;
            %side effects
            obj.zzzComputeMask();
        end
        
        function set.bidirectional(obj,val)
            %validation
            %obj.zprpAssertNotRunning('bidirectional'); - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'logical'},{'scalar'});
            %set prop
            obj.bidirectional = val;
            %side effects
            obj.zzzComputeMask();
            obj.flagResizeAcquisition = true;
        end
        
        function set.periodClockIn(obj,val)
            %validation
            obj.zprpAssertNotRunning('periodClockIn');
            %set prop
            obj.periodClockIn = val;
        end
        
        function set.acqTriggerIn(obj,val)
            %validation
            obj.zprpAssertNotRunning('acqTriggerIn');
            %set prop
            obj.acqTriggerIn = val;
        end
        
        function set.acqTriggerTypeExternal(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            
            if val
                obj.hFpga.AcqTriggerType = 'External or Software';
            else
                obj.hFpga.AcqTriggerType = 'Software';
            end
            
            obj.acqTriggerTypeExternal = val;
        end

        function set.frameClockOut(obj,val)
            %validation
            obj.zprpAssertNotRunning('frameClockOut');
            %set prop
            obj.frameClockOut = val;
        end
        
        function set.beamModifiedLineClockOut(obj,val)
            %validation
            obj.zprpAssertNotRunning('beamModifiedLineClockOut');
            %set prop
            obj.beamModifiedLineClockOut = val;
        end
        
        function set.acqTriggerOut(obj,val)
            %validation
            obj.zprpAssertNotRunning('acqTriggerOut');
            %set prop
            obj.acqTriggerOut = val;
        end
        
        function set.periodClockOnFallingEdge(obj,val)
            %validation
            obj.zprpAssertNotRunning('periodClockOnFallingEdge');
            %set prop
            obj.periodClockOnFallingEdge = val;
        end
        
        function set.acqTriggerOnFallingEdge(obj,val)
            %validation
            obj.zprpAssertNotRunning('acqTriggerOnFallingEdge');
            %set prop
            obj.acqTriggerOnFallingEdge = val;
        end

        function set.nextFileMarkerOnFallingEdge(obj,val)
            %validation
            obj.zprpAssertNotRunning('nextFileMarkerOnFallingEdge');
            %set prop
            obj.nextFileMarkerOnFallingEdge = val;
        end
        
        function set.acqInterruptTriggerOnFallingEdge(obj,val)
            %validation
            obj.zprpAssertNotRunning('acqInterruptTriggerOnFallingEdge');
            %set prop
            obj.acqInterruptTriggerOnFallingEdge = val;
        end  
        
        function set.scannerFrequency(obj,val)
            %validation
            %obj.zprpAssertNotRunning('scannerFrequency');  - only works with submodels, otherwise breaks MVC bindings.
            validateattributes(val,{'numeric'},{'positive' 'finite' 'scalar'});
            %set prop
            obj.scannerFrequency = val;
            %side effects            
            obj.zzzComputeMask();
        end        
        
        function set.frameAcquiredFcn(obj,val)
            %vaidation
            obj.zprpAssertNotRunning('frameAcquiredFcn');
            if isempty(val)
                val = [];
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end

            %set prop
            obj.frameAcquiredFcn = val;
            %side effects            
            ResonantAcqMex(obj,'registerFrameAcqFcn',val);            
        end
        
        function set.loggingAverageFactor(obj, val)
            obj.loggingAverageFactor = val;
            obj.flagResizeAcquisition = true;            
        end
        
        function set.loggingEnable(obj, val)
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.loggingEnable = val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingFullFileName(obj, val)
            obj.loggingFullFileName = val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingFileCounter(obj, val)
           obj.loggingFileCounter = val;
           obj.flagResizeAcquisition = true;
        end
        
        function set.loggingOpenModeString(obj, val)
            obj.loggingOpenModeString = val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingHeaderString(obj, val)
            obj.loggingHeaderString = val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingFramesPerFile(obj, val)
           obj.loggingFramesPerFile = val;
           obj.flagResizeAcquisition = true;            
        end
        
        function set.loggingChannelsArray(obj, val)
            obj.loggingChannelsArray = val;
            obj.numLoggingChannels = numel(val);            
            obj.flagResizeAcquisition = true;
        end
    end
    
    %% Property Access Methods for Live Acquisition Parameters
    methods
        function set.channelsInvert(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            obj.hFpga.AcqParamLiveInvertChannels = val;
            obj.channelsInvert = val;
        end
        
        function set.channelOffsets(obj,val)
            validateattributes(val,{'numeric'},{'vector','numel',4});
            obj.fpgaUpdateLiveAcquisitionParameters('channelOffsets');
            obj.channelOffsets = val;
        end
        
        function set.channelsInputRanges(obj,val)
            validateattributes(val,{'cell'},{'numel', 4});
            
            switch obj.flexRioAdapterModule
                case {'NI5732','NI5734'}
                    for channelNumber = 1:obj.adapterModuleChannelCount
                        channelRange = val{channelNumber};
                        validateattributes(channelRange,{'numeric'},{'numel', 2});
                        channelUpperLimit = channelRange(2);
                        
                        % Execute user command
                        userCommand = 2; % User command for gain settings (Refer to FlexRIO help)
                        userData0 = channelNumber - 1; %channel Number on FPGA is zero-based
                        userData1 = obj.CHANNEL_INPUT_RANGE_FPGA_COMMAND_DATA_MAP(channelUpperLimit);
                        
                        obj.sendNonBlockingAdapterModuleUserCommand(userCommand,userData0,userData1);
                
                        % set channel property (with workaround for accessing cell
                        % elements of an object
                        channelRanges = obj.channelsInputRanges;
                        channelRanges{channelNumber} = channelRange;
                        obj.channelsInputRanges = channelRanges;
                    end
                    obj.channelsInputRanges = val; % if adapter module only has 2 channels, still set all 4 values appropriately
                case 'NI5751'
                    % the input range of the 5751 is fixed at 2Vpp
                    channelRanges = {};
                    for channelNumber = 1:obj.adapterModuleChannelCount
                        channelRanges{channelNumber} = [-1,1];
                    end
                    obj.channelsInputRanges = channelRanges;
                otherwise
                    assert(false);
            end
        end
        
        function set.channelsFilterType(obj,val)
            switch val
                case 'Bypass'
                    filterType = 0;   
                case 'Elliptic'
                    filterType = 1;
                case 'Bessel'
                    filterType = 2;
                otherwise
                    assert(false,'Not a valid filter type: %s\n',val);
            end

			if strcmpi(obj.flexRioAdapterModule,'NI5751')
			    fprintf('The NI-57571 adapter module does not support anti-aliasing filters.')
				obj.channelsFilterType = 'Bypass';
			    return % the 5751 does not support any filters
			end
            
            userCommand = 1; % User command for filter settings (Refer to FlexRIO help) 
            
            for channelNumber = 0:(obj.adapterModuleChannelCount - 1)
                obj.sendNonBlockingAdapterModuleUserCommand(userCommand,channelNumber,filterType);
            end
            
            obj.channelsFilterType = val;
        end
        
        function set.singleChannelNumber(obj,val)
            %validation - channel numbers in Matlab are 1 based {1,2,3,4}
            validateattributes(val,{'numeric'},{'positive' 'finite' 'scalar' 'integer'});
            %set prop
            obj.singleChannelNumber = val;
            %side effects
            obj.fpgaUpdateLiveAcquisitionParameters('singleChannelNumber');
        end
        
        function set.periodClockPhase(obj,val)
            %validation
            validateattributes(val,{'numeric'},{'finite' 'scalar'});
            %set prop
            obj.periodClockPhase = val;
            %side effects
            obj.fpgaUpdateLiveAcquisitionParameters('periodClockPhase');
        end
        
        function set.beamOverScan(obj,val)
            %validation
            validateattributes(val,{'numeric'},{'finite' 'vector'});
            assert(isequal(size(val),[1 2]),'beamOverScan must be a vector of size two');
            %set prop
            obj.beamOverScan = val;
            %side effects
            obj.fpgaUpdateLiveAcquisitionParameters('beamOverScan');     
        end
        

       function set.reverseLineRead(obj,val)
            %validation
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.reverseLineRead = val;
            %side effects
            obj.fpgaUpdateLiveAcquisitionParameters('reverseLineRead');
       end  
    end
    
    %Property-access helpers
    methods (Hidden)
        function zprpUpdateMask(obj)
            obj.dispDbgMsg('Sending Mask to FPGA');
            
            % generate the mask write indices and cast the data to the
            % right datatype
            maskWriteIndices = cast(0:(length(obj.mask)-1),'uint16');
            maskData = cast(obj.mask','int16');
            
            % interleave the indices with the mask data and recast it into
            % a uint32. This is the format the MasktoFPGA FIFO expects
            maskToSend = reshape([maskData;maskWriteIndices],1,[]);
            maskToSend = typecast(maskToSend,'uint32');
            
            try
%                 Element by element write of mask array to FPGA.
%                 for i = 1:length(obj.mask)
%                     obj.hFpga.MaskWriteIndex = i-1;
%                     obj.hFpga.MaskElementData = obj.mask(i);
%                     
%                     obj.hFpga.MaskDoWriteElement = true;
%                 end
                
                % Stream Mask to FPGA with a DMA FIFO
                if (~obj.simulated)
                   obj.hFpga.fifo_MaskToFPGA.write(maskToSend);
                end
                            
                obj.hFpga.AcqParamSamplesPerRecord = obj.samplesPerPeriod;
            catch ME
                error('Error sending mask to FPGA device: \n%s',ME.message);
            end
            
            obj.flagUpdateMask = false;
        end
        
        function zprpAssertNotRunning(obj,propName)
            assert(~obj.acqRunning,'Cannot set property ''%s'' while acquisition is running',propName);            
        end
       
        function zprpResizeAcquisition(obj)    
            obj.frameSizePixels = obj.pixelsPerLine * obj.linesPerFrame; %not including frame tag

            if obj.multiChannel
                fifoElementSizeBytes = obj.FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN;
            else
                fifoElementSizeBytes = obj.FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN;
            end
            
            obj.tagSizeFifoElements = (obj.FRAME_TAG_SIZE_BYTES / fifoElementSizeBytes) * obj.frameTagging ;
            assert(obj.tagSizeFifoElements == floor(obj.tagSizeFifoElements),'Frame Tag Byte Size must be an integer multiple of FIFO Element Byte Size');
            
            obj.frameSizeFifoElements = obj.frameSizePixels + obj.tagSizeFifoElements;
            obj.frameSizeBytes = obj.frameSizeFifoElements * fifoElementSizeBytes;
            
            if (~obj.simulated)
                %Configure FIFO managed by FPGA interface
                if obj.multiChannel
                    obj.hFpga.fifo_MultiChannelToHostU64.configure(obj.frameSizeFifoElements*obj.fifoSizeFrames);
                    obj.hFpga.fifo_MultiChannelToHostU64.start();
                else
                    obj.hFpga.fifo_SingleChannelToHostI16.configure(obj.frameSizeFifoElements*obj.fifoSizeFrames);
                    obj.hFpga.fifo_SingleChannelToHostI16.start();
                end
            end
                        
            %Configure queue(s) managed by MEX interface
            ResonantAcqMex(obj,'resizeAcquisition');          
            obj.flagResizeAcquisition = false;
        end
    end
    
    %% HIDDEN METHODS
    methods (Hidden)        
        function zzzComputeMask(obj)
            if obj.delayMaskComputation
                return;
            end
            
            [obj.mask, samplesPerPixel, samplesToSkip] = scanimage.util.computeresscanmask(...
                obj.scannerFrequency, obj.sampleRate, obj.fillFraction, obj.pixelsPerLine, obj.bidirectional);
            obj.flagUpdateMask = true;
                                        
            %% Side effects
            obj.samplesPerPeriod = sum(abs(obj.mask));
            obj.samplesPerLine = sum(samplesPerPixel);
            obj.samplesPerLineSwitch = samplesToSkip;
            obj.scanLineDuration = obj.samplesPerLine / obj.sampleRate;
        end
        
        function status = sendAdapterModuleUserCommand(obj,userCommand,userData0,userData1)
            obj.fpgaCheckAdapterModuleInitialization();
            
            if isempty(strfind(obj.flexRioAdapterModule,'NI573'))
                obj.dispDbgMsg('Adapter module %s does not support user commands',obj.flexRioAdapterModule);
                status = 0;
                return
            end

            % Wait for module to be ready to accept user command input
            assert(obj.waitModuleUserCommandIdle,'Module is not idle - failed to send command');

            % Execute user command
            obj.hFpga.AdapterModuleUserCommand = userCommand;
            obj.hFpga.AdapterModuleUserData0 = userData0;
            obj.hFpga.AdapterModuleUserData1 = userData1;
            obj.hFpga.AdapterModuleDoUserCommandCommit = true;
            obj.cmdSent = true;

            % Check user command return value
            assert(obj.waitModuleUserCommandIdle,'Module is not idle - failed to send command');
            status = obj.hFpga.AdapterModuleUserCommandStatus;
        end
        
        function sendNonBlockingAdapterModuleUserCommand(obj,userCommand,userData0,userData1)
			if isempty(strfind(obj.flexRioAdapterModule,'NI573'))
                obj.dispDbgMsg('Adapter module %s does not support user commands',obj.flexRioAdapterModule);
                return
            end
			
            obj.fpgaCheckAdapterModuleInitialization();
            % Wait for module to be ready to accept user command input
            assert(obj.waitModuleUserCommandIdle,'Module is not idle - failed to send command');

            % Execute user command
            obj.hFpga.AdapterModuleUserCommand = userCommand;
            obj.hFpga.AdapterModuleUserData0 = userData0;
            obj.hFpga.AdapterModuleUserData1 = userData1;
            obj.hFpga.AdapterModuleDoUserCommandCommit = true;
            obj.cmdSent = true;
        end
    end
    
    %% Private Methods for FPGA Access
    methods (Access = private)
        function fpgaUpdateAcquisitionParameters(obj)
            obj.dispDbgMsg('Updating Acquisition Parameters on FPGA');
            
            obj.hFpga.AcqParamRecordsPerFrame = obj.periodsPerFrame;
            obj.hFpga.AcqParamFramesPerGrab = obj.framesPerAcquisition;
            obj.hFpga.AcqParamGrabsPerAcquisition = obj.acquisitionsPerAcquisitionMode;
            obj.hFpga.AcqParamFlybackPeriods = obj.flybackLinesPerFrame / 2^obj.bidirectional;
            obj.hFpga.AcqParamFrameTaggingEnable = obj.frameTagging;
            obj.hFpga.DebugProduceDummyData = obj.dummyData;
            
            obj.acqTriggerTypeExternal = obj.acqTriggerTypeExternal; %Ensure the correct trigger type is enabled

            % Configure Trigger Lines
            obj.hFpga.PeriodClockTerminalIn = obj.periodClockIn;
            obj.hFpga.AcqTriggerTerminalIn = obj.acqTriggerIn;
            obj.hFpga.AdvanceTriggerTerminalIn = obj.nextFileMarkerIn;
            obj.hFpga.StopTriggerTerminalIn = obj.acqInterruptTriggerIn;
            
            obj.hFpga.PeriodClockOnFallingEdge = obj.periodClockOnFallingEdge;
            obj.hFpga.AcqTriggerOnFallingEdge = obj.acqTriggerOnFallingEdge;
            obj.hFpga.AdvanceTriggerOnFallingEdge = obj.nextFileMarkerOnFallingEdge;
            obj.hFpga.StopTriggerOnFallingEdge = obj.acqInterruptTriggerOnFallingEdge;
            
            obj.hFpga.FrameClockTerminalOut = obj.frameClockOut;
            obj.hFpga.BeamClockTerminalOut = obj.beamModifiedLineClockOut;
            obj.hFpga.AcqTriggerTerminalOut = obj.acqTriggerOut;

            %From Georg:
            %BeamClockMode values: 'Trigger' or 'Toggle'
            %
            %Trigger: the clock signal is high for the duration of the beam
            %Toggle:  the clock signal generates a 75ns pulse when the beam changes its on/off status
            obj.hFpga.BeamClockMode = 'Trigger'; 
            
            %additionally update the Live Acquisition Parameters
            if (~obj.simulated)
                obj.fpgaUpdateLiveAcquisitionParameters('forceall');
            end
        end

        
        function fpgaUpdateLiveAcquisitionParameters(obj,property)
            if obj.acqRunning || strcmp(property,'forceall')
                obj.dispDbgMsg('Updating FPGA Live Acquisition Parameter: %s',property);
               
                if updateProp('singleChannelNumber')
                        % Decrement because the FPGA channel numbers are
                        % 0-based wheres in Matlab 1-based numbers are used
                        obj.hFpga.AcqParamLiveSelectSingleChannel = obj.singleChannelNumber - 1;
                end
                
                if updateProp('periodClockPhase') 
                        obj.hFpga.AcqParamLiveTriggerHoldOff = obj.triggerHoldOff;
                        obj.hFpga.AcqParamLivePreTriggerSamples = obj.preTriggerSamples;
                end
                
                if updateProp('beamOverScan')
                        beamTiming = obj.beamTiming;
                        obj.hFpga.BeamClockOnForward   = beamTiming(1);
                        obj.hFpga.BeamClockOffForward  = beamTiming(2);
                        obj.hFpga.BeamClockOnBackward  = beamTiming(3);
                        obj.hFpga.BeamClockOffBackward = beamTiming(4);
                end
                
                if updateProp('reverseLineRead') 
                        obj.hFpga.AcqParamLiveReverseLineRead = obj.reverseLineRead;
                end
                
                if updateProp('channelOffsets')
                        obj.hFpga.AcqParamLiveChannelOffsets = - obj.channelOffsets;
                end
            end
            
            % Helper function to identify which properties to update
            function tf = updateProp(currentprop)
                tf = strcmp(property,'forceall') || strcmp(property,currentprop);
            end
        end        
        
        function fpgaReset(obj)
            obj.dispDbgMsg('Resetting FPGA');
            if (~obj.simulated)
                obj.hFpga.reset();
                obj.hFpga.run();
            end
            obj.dispDbgMsg('Resetting FPGA completed');
        end
        
        function fpgaCheckAdapterModuleInitialization(obj)
            obj.dispDbgMsg('checking FPGA Adapter Module Initialization');
            timeout = obj.HW_TIMEOUT;           %timeout in seconds
            pollinginterval = obj.HW_DETECT_POLLING_INTERVAL; %pollinginterval in seconds
            while obj.hFpga.AdapterModuleInitializationDone == 0
                pause(pollinginterval);
                timeout = timeout - pollinginterval;
                if timeout <= 0
                    error('Initialization of adapter module timed out')
                end
            end
            obj.dispDbgMsg('FPGA Adapter Module is initialized');
        end
        
        function fpgaDetectAdapterModule(obj)
            obj.dispDbgMsg('Detecting FlexRIO Adapter Module');
            timeout = obj.HW_DETECT_TIMEOUT;          %timeout in seconds
            pollinginterval = obj.HW_DETECT_POLLING_INTERVAL; %pollinginterval in seconds
            while obj.hFpga.AdapterModulePresent == 0 || obj.hFpga.AdapterModuleIDInserted == 0
                pause(pollinginterval);
                timeout = timeout - pollinginterval;
                if timeout <= 0
                    error('No FlexRIO Adapter Module installed');
                end
            end
            
            % get the adapter module name 
            expectedModuleID = obj.hFpga.AdapterModuleIDExpected;
            insertedModuleID = obj.hFpga.AdapterModuleIDInserted;
            
            expectedModuleName = obj.ADAPTER_MODULE_MAP(expectedModuleID);
            if isKey(obj.ADAPTER_MODULE_MAP,insertedModuleID)
                insertedModuleName = obj.ADAPTER_MODULE_MAP(insertedModuleID);
            else
                insertedModuleName = sprintf('Unknown Module ID: %d', insertedModuleID);
            end
            
            %check if right module is installed
            assert(obj.hFpga.AdapterModuleIDMismatch == 0,...
                'Wrong Adapter Module installed. Expected Module: ''%s'', Inserted Module:''%s''',...
                    expectedModuleName,insertedModuleName);
                
            %get the module sampling rate
            obj.sampleRate = obj.ADAPTER_MODULE_SAMPLING_RATE_MAP(insertedModuleName);
            obj.bitDepth = obj.ADAPTER_MODULE_ADC_BIT_DEPTH(insertedModuleName);
            obj.flexRioAdapterModule = insertedModuleName;
            obj.adapterModuleChannelCount = obj.ADAPTER_MODULE_CHANNEL_COUNT(obj.flexRioAdapterModule);
            
            obj.dispDbgMsg('FlexRIO Adapter Module detected: % s',insertedModuleName);
            obj.dispDbgMsg('FlexRIO Acquisition Sampling Rate: % dHz',obj.sampleRate)
            obj.dispDbgMsg('FlexRIO Channel Count: %d',obj.adapterModuleChannelCount);
            obj.dispDbgMsg('FlexRIO Channel Resolution: %d bits',obj.bitDepth);
        end
        
        function fpgaSelectFifo(obj)
            obj.hFpga.FifoEnableSingleChannel = ~obj.multiChannel;
            obj.hFpga.FifoEnableMultiChannel = obj.multiChannel;
        end
        
        
        function fpgaStopFifo(obj)
            obj.dispDbgMsg('Stopping FIFO');
            if obj.multiChannel
                obj.hFpga.fifo_MultiChannelToHostU64.stop();
            else
                obj.hFpga.fifo_SingleChannelToHostI16.stop();
            end
        end
        
        
        function idle = waitModuleUserCommandIdle(obj)
            % Wait for FPGA to be ready to accept user command inputs
            idle = true;
            timeout = obj.HW_TIMEOUT;           %timeout in seconds
            pollinginterval = obj.HW_POLLING_INTERVAL; %pollinginterval in seconds
            while obj.hFpga.AdapterModuleUserCommandIdle == 0
                pause(pollinginterval);
                timeout = timeout - pollinginterval;
                if timeout <= 0
                    idle = false;
                    return;
                end
            end
            
            status = obj.hFpga.AdapterModuleUserCommandStatus;
            if status && obj.cmdSent
                cmd = int2str(obj.hFpga.AdapterModuleUserCommand);
                most.idioms.warn(['Previous FPGA adapter module command (''' cmd ''') failed with status code ''' int2str(status) '''.']);
            end
        end
        
    end
    
    %% Private Methods for Debugging
    methods (Access = private)
        function dispDbgMsg(obj,varargin)
            if obj.debugOutput
                fprintf(horzcat('Class: ',class(obj),': ',varargin{1},'\n'),varargin{2:end});
            end
        end
    end
end

%--------------------------------------------------------------------------%
% ResonantAcq.m                                                            %
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
