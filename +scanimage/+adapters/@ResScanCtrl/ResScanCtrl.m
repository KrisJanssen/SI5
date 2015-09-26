classdef ResScanCtrl < most.MachineDataFile
    %SCANNINGGALVO
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)    
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ResScanCtrl';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end

    properties
        resonantScannerFreq = 7910;          % the expected frequency of the resonant scanner in Hz. can only be updated while the scanner is idle
        periodsPerFrame = 256;               % the number of periods per frame. can only be updated while the scanner is idle
        galvoFlyBackPeriods = 1;             % the number of scanner periods to fly back the galvo. can only be updated while the scanner is idle
        galvoParkDeg = 0;                    % the position of the galvo when the scanner is inactive in optical degrees
        galvoInvertScanDirection = false;    % specifies if the ramp that controls the Galvo is inverted
        zoomFactor = 1;
        galvoFillFraction = 1;
        galvoScanAngleMultiplier = 1;
        galvoOffsetDeg = 0;
        resonantScannerZoomOutput = true;
        
        periodClockIn = 'PFI0';         % String identifying the input terminal connected to the period clock. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'
        frameClockIn = 'PFI1';          % String identifying the input terminal connected to the frame clock. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'
                
        %simulated mode
        simulated=false;
    end
    
    events
        resonantScannerOutputVoltsUpdated
    end
    
    % Live Values - these properties can be updated during an active acquisition
    properties (Hidden, SetAccess = private)
        galvoAmplitudeDeg = 0;              % the scan amplitude of the galvo in optical degrees
        resonantScannerRangeDeg = 0;        % the resonant scanner zoom level in optical degress
    end
    
    properties (Dependent)
        galvoAmplitudeVolts;
        galvoOffsetVolts;                   
        galvoParkVolts;                  
        resonantScannerRangeVolts;
    end
    
    % Internal Parameters
    properties (Dependent, Hidden)
       galvoScanDur;
       galvoScanOutputPts;
    end
    
    properties (SetAccess = private, Hidden)
        hModel;
        
        hDaqSystem;
        hDaqDevice;
              
        hCtrTaskMeasResPeriod;
        hCtrChanMeasResPeriod;
        
        hAOTaskResonantScannerZoom;
        
        hAOTaskGalvo;
        hAOChanGalvo;
        hCtrMSeriesSampClk;
        useSamplClkHelperTask = false;
        
        hAOTaskGalvoPark;
        
        acquisitionActive = false;
        rateAOSampClk;
        resScanBoxCtrlInitialized;
        
        resonantScannerActive = false;
        resonantScannerLastUpdate = clock;
        resonantScannerLastWrittenValue;
    end
    
    %% Lifecycle
    methods
        function obj = ResScanCtrl(hModel,simulated)
            if nargin < 1 || isempty(hModel)
                hModel = [];
            end
            
            if nargin < 2 || isempty(simulated)
                obj.simulated=false;
            else
                obj.simulated=simulated;
            end
            
            obj.hModel = hModel;
            
            %Get property values from machineDataFile
            validateattributes(obj.mdfData.scanCtrlDeviceName,{'char'},{'vector','nonempty'});
            validateattributes(obj.mdfData.galvoAOChanID,{'numeric'},{'scalar','nonnegative','nonempty'});
            validateattributes(obj.mdfData.resonantZoomAOChanID,{'numeric'},{'scalar','nonnegative','nonempty'});
            validateattributes(obj.mdfData.chanCtrMeasResPeriod,{'numeric'},{'scalar','nonnegative','nonempty'});            
            
            validateattributes(obj.mdfData.galvoVoltsPerOpticalDegree,{'numeric'},{'scalar','finite','positive'});
            validateattributes(obj.mdfData.rScanVoltsPerOpticalDegree,{'numeric'},{'scalar','finite','positive'});
            
            validateattributes(obj.mdfData.resonantScannerSettleTime,{'numeric'},{'scalar','nonnegative','nonempty'});            

            if (~obj.simulated)
                obj.initializeTasks();
                obj.detectPxiChassis();
            end
            
            obj.zoomFactor = obj.zoomFactor; %self initialize output
        end
        
        function delete(obj)
            try
                if obj.acquisitionActive
                    obj.stop();
                end

                if ~obj.simulated
                    % clear DAQmx buffered Tasks
                    if most.idioms.isValidObj(obj.hCtrMSeriesSampClk)
                        obj.hCtrMSeriesSampClk.clear();
                    end
                    obj.hCtrTaskMeasResPeriod.clear();
                    obj.hAOTaskGalvo.clear();
                    
                    % force AO Outputs to 0 Volts
                    obj.hAOTaskGalvoPark.writeAnalogData(obj.mdfData.galvoParkDegrees);
                    obj.hAOTaskResonantScannerZoom.writeAnalogData(0);
                    
                    % clear unbuffered Tasks
                    obj.hAOTaskGalvoPark.clear();
                    obj.hAOTaskResonantScannerZoom.clear();
                    
                    % explicitly delete all Tasks
                    %                 delete(obj.hCtrTaskMeasResPeriod);
                    %                 delete(obj.hAOTaskGalvo);
                    %                 delete(obj.hAOTaskGalvoPark);
                    %                 delete(obj.hAOTaskResonantScannerZoom);
                end
            catch ME
                obj.hDaqDevice.reset(); % hard reset the device to clear all routes and delete all tasks
                rethrow(ME);
            end
            % no need to delete the singleton hDaqSystem Object
            % no need to delete the hDaqDevice Object
        end
    end
    
    %% Public Methods
    methods        
        function start(obj)
            assert(~obj.acquisitionActive,'Acquisition is already active');      
            if (~obj.simulated)
                % Initialize Galvo and Resonant Scanner so they have some time
                % to power up, while the tasks configuration is updated
                obj.forceGalvoVolts(obj.galvoScanOutputPts(1));
                obj.resonantScannerActivate(true);
                
                % Reconfigure the Tasks for the selected acquisition Model
                obj.updateTaskCfg();
                %Todo: Is this pause needed for the Resonant Scanner to reach
                %its amplitude and send valid triggers?
                obj.resonantScannerWaitSettle();
                
                obj.hAOTaskGalvo.start();
                if obj.useSamplClkHelperTask
                    obj.hCtrMSeriesSampClk.start();
                end 
            end
            
            obj.acquisitionActive = true;  
        end
        
        function stop(obj)
            if (~obj.simulated)
                if obj.useSamplClkHelperTask
                    obj.hCtrMSeriesSampClk.abort();
                    obj.hCtrMSeriesSampClk.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
                end 
                
                obj.hAOTaskGalvo.abort();
                obj.hAOTaskGalvo.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            end
                        
            %Park scanner
            % parkGalvo() has to be called after acquisitionActive is set to
            % false, otherwise we run into an infinite loop
            obj.acquisitionActive = false;
            if (~obj.simulated)
                obj.parkGalvo();
            end
            obj.resonantScannerActivate(false);
        end
        
        function resonantScannerFreq = calibrateResonantScannerFreq(obj,averageNumSamples)
           if obj.acquisitionActive
               resonantScannerFreq = NaN; %#ok<NASGU>
               error('Measurement cannot be performed during active acquisition');
           end
           
           if nargin < 2 || isempty(averageNumSamples)
               averageNumSamples = 100;
           end
           
           if ~obj.simulated
               resonantPeriods = obj.hCtrTaskMeasResPeriod.readCounterData(averageNumSamples,6,averageNumSamples);
               resonantPeriod = mean(resonantPeriods); %ignore the first second of the measurement
               resonantScannerFreq = 1/resonantPeriod;
           else
               resonantScannerFreq = obj.hModel.resonantScannerFreq;
           end
           
           obj.resonantScannerFreq = resonantScannerFreq;
        end
        
        function resonantScannerActivate(obj,activate)
           if nargin < 2 || isempty(activate)
               activate = true;
           end
           
           if activate
               obj.resonantScannerActive = true;
               obj.resonantScannerUpdateOutputVolts();
           else
               obj.resonantScannerActive = false;
               obj.resonantScannerUpdateOutputVolts();
           end           
        end
        
        function resonantScannerWaitSettle(obj,settleTime)
            if nargin < 2 || isempty(settleTime)
                settleTime = obj.mdfData.resonantScannerSettleTime;
            end
            
            timeSinceLastAOUpdate = etime(clock,obj.resonantScannerLastUpdate);
            timeToWait = settleTime-timeSinceLastAOUpdate;
            
            if timeToWait > 0
                %fprintf('Waiting %f seconds for resonant scanner to settle\n',timeToWait);
                pause(settleTime-timeSinceLastAOUpdate);
            end
        end
        
        function centerGalvo(obj)
            assert(~obj.acquisitionActive,'Cannot center galvo while scanner is active');
            obj.forceGalvoVolts(obj.galvoOffsetVolts);
        end
                        
        function parkGalvo(obj)
           assert(~obj.acquisitionActive,'Cannot park galvo while scanner is active');
           obj.forceGalvoVolts(obj.galvoParkVolts);
        end
    end
    
    %% Private Methods   
    methods (Access = private)
        function resonantScannerUpdateOutputVolts(obj)
            if obj.resonantScannerActive
                newValue = obj.resonantScannerRangeVolts;
            else
                newValue = 0;
            end
            
            if newValue ~= obj.resonantScannerLastWrittenValue
                obj.resonantScannerLastUpdate = clock;
            end
            
            obj.resonantScannerLastWrittenValue = newValue;

            if (~obj.simulated) && obj.resonantScannerZoomOutput
                obj.hAOTaskResonantScannerZoom.writeAnalogData(newValue);
            end
            obj.notify('resonantScannerOutputVoltsUpdated');
        end
        
        function initializeTasks(obj)
            import dabs.ni.daqmx.*;
 
            try
            % get the singleton DAQmx System Object and a handle to the
            % DAQ-Device
            obj.hDaqSystem = dabs.ni.daqmx.System();
            obj.hDaqDevice = dabs.ni.daqmx.Device(obj.mdfData.scanCtrlDeviceName);
            
            % TODO: For debugging we just close Matlab without calling the
            % deconstructor. This might leave some routes on the device
            % active. To work around this, the device is hard reset here.
            % This should be handled better later.
            fprintf('Hard Resetting device ''%s'' to clear all previously set routes\n',...
                        obj.mdfData.scanCtrlDeviceName);
            obj.hDaqDevice.reset();
            
            % create Tasks (%HACK: safeCreateTask should not be needed)
            obj.hAOTaskGalvo = scanimage.util.priv.safeCreateTask('GalvoCtrlGalvoPosition');
            obj.hAOTaskResonantScannerZoom = scanimage.util.priv.safeCreateTask('GalvoCtrlresonantScannerZoomVolts');
            obj.hAOTaskGalvoPark = scanimage.util.priv.safeCreateTask('ParkGalvoCtrlAO');
            obj.hCtrTaskMeasResPeriod = scanimage.util.priv.safeCreateTask('MeasureResonantScannerFreq');
            
            %set up Ctr Task to measure the period of the Resonant Scanner
            %this is the same counter channel as the counter for the frame
            % clock, so it can only be run while the acquisition is not active
            obj.hCtrChanMeasResPeriod = obj.hCtrTaskMeasResPeriod.createCIPeriodChan(obj.mdfData.scanCtrlDeviceName,obj.mdfData.chanCtrMeasResPeriod);
            obj.hCtrChanMeasResPeriod.set('periodTerm',obj.qualifyTermName(obj.periodClockIn));
            

            %set up buffered AO Task to control the Galvo Scan
            obj.hAOChanGalvo = obj.hAOTaskGalvo.createAOVoltageChan(obj.mdfData.scanCtrlDeviceName,obj.mdfData.galvoAOChanID);
            obj.rateAOSampClk = obj.hAOTaskGalvo.get('sampClkMaxRate');

            switch obj.hDaqDevice.productCategory
                case 'DAQmx_Val_XSeriesDAQ'
                    obj.hAOTaskGalvo.cfgSampClkTiming(obj.rateAOSampClk,'DAQmx_Val_FiniteSamps',length(obj.galvoScanOutputPts));
                    obj.hAOTaskGalvo.cfgDigEdgeStartTrig(obj.qualifyTermName(obj.frameClockIn));
                    obj.hAOTaskGalvo.set('startTrigRetriggerable',1);
                    obj.useSamplClkHelperTask = false;
                case 'DAQmx_Val_MSeriesDAQ'
                    % the M series does not support native retriggering for
                    % AOs. Workaround: Use counter to produce sample clock
                    obj.hCtrMSeriesSampClk = scanimage.util.priv.safeCreateTask('M-Series helper task');
                    obj.hCtrMSeriesSampClk.createCOPulseChanFreq(obj.mdfData.scanCtrlDeviceName,0,[],obj.rateAOSampClk);
                    obj.hCtrMSeriesSampClk.channels(1).set('pulseTerm',''); % we do not need to export the sample clock to a PFI. delete
                    obj.hCtrMSeriesSampClk.cfgImplicitTiming('DAQmx_Val_FiniteSamps', length(obj.galvoScanOutputPts));
                    obj.hCtrMSeriesSampClk.cfgDigEdgeStartTrig(obj.qualifyTermName(obj.frameClockIn));
                    obj.hCtrMSeriesSampClk.set('startTrigRetriggerable',1);
                    
                    % setup hAOTaskGalvo to use the sample clock generated by the counter
                    samplClkInternalOutputTerm = sprintf('/%sInternalOutput',obj.hCtrMSeriesSampClk.channels(1).chanNamePhysical);
                    obj.hAOTaskGalvo.cfgSampClkTiming(obj.rateAOSampClk,'DAQmx_Val_ContSamps',length(obj.galvoScanOutputPts),samplClkInternalOutputTerm);
                    obj.useSamplClkHelperTask = true;
                otherwise
                    error('Primary DAQ Device needs to be either M-series or X-series');
            end
            
            %set up unbuffered Task to move the Galvo to a given position
            obj.hAOTaskGalvoPark.createAOVoltageChan(obj.mdfData.scanCtrlDeviceName,obj.mdfData.galvoAOChanID);
            obj.parkGalvo();
            
            %set up unbuffered Task to set the resonant scanner zoom level
            obj.hAOTaskResonantScannerZoom.createAOVoltageChan(obj.mdfData.scanCtrlDeviceName,obj.mdfData.resonantZoomAOChanID,[],0,5);
            obj.resonantScannerActivate(false); % set output to zero       
            
            catch ME
                obj.hDaqDevice.reset(); %clear all routes
                delete(obj)
                rethrow(ME);
            end
            
            obj.resScanBoxCtrlInitialized = true;
        end
             
        function updateTaskCfg(obj)
            %make sure buffered tasks are stopped
            if obj.useSamplClkHelperTask
                obj.hCtrMSeriesSampClk.abort();
            end
            
            obj.hAOTaskGalvo.abort();

            galvoScanOutputPoints_ = obj.galvoScanOutputPts;
            if obj.useSamplClkHelperTask
                obj.hCtrMSeriesSampClk.set('sampQuantSampPerChan',length(galvoScanOutputPoints_));
            end
            obj.hAOTaskGalvo.set('sampQuantSampPerChan',length(galvoScanOutputPoints_));
            obj.hAOTaskGalvo.set('bufOutputBufSize',length(galvoScanOutputPoints_));
            obj.hAOTaskGalvo.writeAnalogData(galvoScanOutputPoints_);
        end
        
        function updateLiveValues(obj)
            if (~obj.simulated)
                if obj.acquisitionActive
                    try
                        obj.hAOTaskGalvo.abort();
                        if obj.useSamplClkHelperTask
                            obj.hCtrMSeriesSampClk.abort();
                        end
                        
                        obj.hAOTaskGalvo.writeAnalogData(obj.galvoScanOutputPts);
                        
                        obj.hAOTaskGalvo.start();
                        if obj.useSamplClkHelperTask
                            obj.hCtrMSeriesSampClk.start();
                        end
                    catch ME
                        % ignore DAQmx Error 200015 since it is irrelevant here
                        % Error message: "While writing to the buffer during a
                        % regeneration the actual data generated might have
                        % alternated between old data and new data."
                        if isempty(strfind(ME.message, '200015'))
                            rethrow(ME)
                        end
                    end
                else
                    % if the parking position for the Galvo was updated, apply
                    % the new settings.
                    obj.parkGalvo();
                end
            end
        end

        

        
        function forceGalvoVolts(obj,value)
            if obj.acquisitionActive
                obj.stop();
            end
            
            if (~obj.simulated)
                obj.hAOTaskGalvoPark.writeAnalogData(value);
            end
        end
        
        function qualifiedTermName = qualifyTermName(obj,termName)
            validateattributes(termName,{'char'},{'vector'});
            
            if isempty(termName)
                qualifiedTermName = '';
            elseif isempty(strfind(termName,'/'))
                qualifiedTermName = sprintf('/%s/%s',obj.mdfData.scanCtrlDeviceName,termName); % e.g. '/PXI1Slot3/PFI1'
            else
                qualifiedTermName = termName;
            end
        end
        
        function inPxiChassis = detectPxiChassis(obj)
            inPxiChassis = false;
            if isempty(obj.hModel) || ~isvalid(obj.hModel)
                 % adapter is not called from SI5.m PXI routing is not available
                 return
            end
            
            inPxiChassis = obj.hModel.hTriggerMatrix.isDeviceInMainPxiChassis(obj.mdfData.scanCtrlDeviceName);
            if inPxiChassis
                fprintf('Setting up ResScan for internal PXI routing\n');
                obj.periodClockIn = obj.hModel.hTriggerMatrix.PXI_TRIGGER_MAP('periodClock');
                %fprintf('ResScan: Set periodClockIn to ''%s''\n',obj.periodClockIn);
                obj.frameClockIn = obj.hModel.hTriggerMatrix.PXI_TRIGGER_MAP('frameClock');
                %fprintf('ResScan: Set frameClockIn to ''%s''\n',obj.frameClockIn);
            end
        end
    end
    
    %% Property Access Methods
    methods        
        function dataPoints = get.galvoScanOutputPts(obj)
            numDataPoints = ceil(obj.galvoScanDur*obj.rateAOSampClk);
            
            flybackNumPoints = floor(0.75 * obj.galvoFlyBackPeriods * (obj.rateAOSampClk / obj.resonantScannerFreq)); %Flyback ramp spans half of the galvo flyback period                                                                              
            
            voltageRange = [-obj.galvoAmplitudeVolts/2 obj.galvoAmplitudeVolts/2];
            voltageRange = voltageRange * obj.galvoScanAngleMultiplier * obj.galvoFillFraction;
            voltageRange = voltageRange + obj.galvoOffsetVolts; % Used for shift slow
            
            if obj.galvoInvertScanDirection
                voltageRange = fliplr(voltageRange);
            end
            
            frameDataPoints = linspace(voltageRange(1),voltageRange(2),numDataPoints)';
            flybackDataPoints = linspace(voltageRange(2),voltageRange(1),flybackNumPoints)';
            
            dataPoints = [frameDataPoints; flybackDataPoints];
        end
        
        function value = get.galvoScanDur(obj)
            value = obj.periodsPerFrame/obj.resonantScannerFreq;
        end
    end
    
    %% Property Set Methods
    
   methods
       function set.periodClockIn(obj,value)
           assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','periodClockIn');
           validateattributes(value,{'char'},{'vector','nonempty'});
           
           obj.hCtrChanMeasResPeriod.set('periodTerm',obj.qualifyTermName(value));
           obj.periodClockIn = value;
       end
       
       function set.frameClockIn(obj,value)
           assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','frameClockIn');
           validateattributes(value,{'char'},{'vector','nonempty'});
           
           if obj.useSamplClkHelperTask
               obj.hCtrMSeriesSampClk.cfgDigEdgeStartTrig(obj.qualifyTermName(value));
           else
               obj.hAOTaskGalvo.cfgDigEdgeStartTrig(obj.qualifyTermName(value));
           end
           obj.frameClockIn = value;
       end
       
       function set.zoomFactor(obj,value)
           obj.zoomFactor = value;
           
           %side effects
           refAngularRange = obj.mdfData.refAngularRange;
           obj.galvoAmplitudeDeg = refAngularRange / value;
           obj.resonantScannerRangeDeg = refAngularRange / value;
       end
           
       function set.resonantScannerFreq(obj,value)
           %assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','resonantScannerFreq'); -- can't do this without submodels, otherwise breaks MVC bindings.
           obj.resonantScannerFreq = value;
       end
       
       function set.galvoFlyBackPeriods(obj,value)
           %assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','galvoFlyBackPeriods'); -- can't do this without submodels, otherwise breaks MVC bindings.
           %assert(value >= 1,'galvoFlyBackPeriods must be greater or equal to 1'); 
           obj.galvoFlyBackPeriods = value;
       end
       
       function value = get.galvoAmplitudeVolts(obj)
           value = obj.galvoAmplitudeDeg * obj.mdfData.galvoVoltsPerOpticalDegree;
       end
       
       function set.galvoAmplitudeVolts(obj,value)
           obj.galvoAmplitudeVolts = value / obj.mdfData.galvoVoltsPerOpticalDegree;
       end
       
       function value = get.galvoOffsetVolts(obj)
           value = obj.galvoOffsetDeg * obj.mdfData.galvoVoltsPerOpticalDegree;
       end
       
       %        function set.galvoOffsetVolts(obj,value)
       %            obj.galvoOffsetDeg = value / obj.mdfData.galvoVoltsPerOpticalDegree;
       %        end
      
      function value = get.galvoParkVolts(obj)
          value = obj.mdfData.galvoParkDegrees * obj.mdfData.galvoVoltsPerOpticalDegree;
      end
      
      %       function set.galvoParkVolts(obj,value)
      %           obj.galvoParkDeg = value / obj.mdfData.galvoVoltsPerOpticalDegree;
      %       end
      
      function set.galvoAmplitudeDeg(obj,value)
          obj.galvoAmplitudeDeg = value;
          obj.updateLiveValues();
      end
      
      function set.galvoOffsetDeg(obj,value)
          obj.galvoOffsetDeg = value;
          obj.updateLiveValues();
      end

      function set.galvoParkDeg(obj,value)
          obj.galvoParkDeg = value;
          obj.updateLiveValues();
      end
      
      function set.galvoScanAngleMultiplier(obj,value)
          obj.galvoScanAngleMultiplier = value;
          obj.updateLiveValues();
      end
      
      function set.galvoInvertScanDirection(obj,value)
          obj.galvoInvertScanDirection = value;
          obj.updateLiveValues();
      end
      
      function value = get.resonantScannerRangeVolts(obj)
         value = obj.resonantScannerRangeDeg * obj.mdfData.rScanVoltsPerOpticalDegree;
      end
      
      function set.resonantScannerRangeVolts(obj,value)
          obj.resonantScannerRangeDeg = value / obj.mdfData.rScanVoltsPerOpticalDegree;
      end
      
      function set.resonantScannerRangeDeg(obj,value)
          obj.resonantScannerRangeDeg = value;
          
          %side effect
          obj.resonantScannerUpdateOutputVolts();
      end
   end
end

%--------------------------------------------------------------------------%
% ResScanCtrl.m                                                            %
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
