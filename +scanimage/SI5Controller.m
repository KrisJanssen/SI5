classdef SI5Controller < most.Controller
    %SI5CONTROLLER most.Controller class for the ScanImage application
        
    %% ABSTRACT PROPERTY REALIZATIONS (most.Controller)
    properties (SetAccess=protected)
        propBindings = lclInitPropBindings();
    end
    
    properties (Hidden, Dependent)
        mainControlsStatusString;
    end
    
    properties (Hidden)
        beamProp2Control; %Scalar struct. Fields: SI beam property name. values: uicontrol handle arrays for that prop. The properties in this struct must be beam-indexed (with round brackets).
    end
    
    %% PUBLIC PROPERTIES
    properties
        beamDisplayIdx=1; %Index of beam whose properties are currently displayed/controlled
        channelsTargetDisplay; %A value indicating 'active' channel display, or Inf, indicating the merge display figure. If empty, no channel is active.
    end
    
    %% PRIVATE PROPERTIES
    properties(Hidden)
        usrSettingsPropListeners; % col vec of listener objects used for userSettingsV4
        
    end
    
    properties(Hidden,Dependent)
        hMainPbFastCfg;  % 6x1 vector of MainControls fastCfg buttons
    end
    
    %% USER FUNCTION RELATED PROPERTIES
    properties(Hidden,Dependent)
        userFunctionsViewType; % string enum; either 'CFG', 'USR', or 'none'.
        userFunctionsCurrentEvents;
        userFunctionsCurrentProp;
    end
    % end user function related properites
    
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        
        function obj = SI5Controller(hModel)
            baseDirectory = fileparts(which('scanimage5'));
            addpath(fullfile(baseDirectory, 'guis'));
            addpath(fullfile(baseDirectory, 'guis', 'icons'));
            
            obj = obj@most.Controller(hModel,...
                {'mainControlsV4' 'imageControlsV4' 'configControlsV4' 'channelControlsV4' 'motorControlsV4' 'fastZControlsV4' 'powerControlsV4'}, ...
                {'configControlsV4','userSettingsV4','fastConfigurationV4','userFunctionControlsV4','triggerControlsV5','posnControlsV4','pmtControlsV5','bScope2ControlsV5'});
            
            %Capture keypresses for FastCfg F-key behavior. At moment, set
            %KeyPressFcn for all figures, uicontrols, etc so that all
            %keypresses over SI guis are captured. This can be modified
            %if/when certain figures/uicontrols need their own KeyPressFcns.
            structfun(@(handles)obj.ziniSetKeyPressFcn(handles),obj.hGUIData);
            
            %GUI Initializations
            obj.ziniMainControls();
            obj.ziniConfigControls();
            obj.ziniImageControls();
            obj.ziniChannelControls();
            obj.ziniPowerControls();
            obj.ziniMotorControls();
            obj.ziniPosnControls();
            obj.ziniPmtControls(); %  This is currently done in PMT, as a workaround for model/controller initialization
            obj.ziniFastZControls();
            obj.ziniBScope2Controls();
            obj.ziniUsrSettingsGUI();
            obj.ziniTriggers();
            obj.ziniFigPositions();
            obj.ziniRegisterFigs();
            
            % imageControlsV4.pmTargetFigure
            optionStrings = cell(obj.hModel.MAX_NUM_CHANNELS+2,1);
            optionStrings{1} = 'None';
            for i = 1:obj.hModel.MAX_NUM_CHANNELS
                optionStrings{i+1} = sprintf('Chan %d',i);
            end
            optionStrings{end} = 'Merge';
            set(obj.hGUIData.imageControlsV4.pmTargetFigure,'String',optionStrings);
            set(obj.hGUIData.imageControlsV4.pmTargetFigure,'Value',1);
            
            %Listener Initializations
            obj.hModel.addlistener('motorPositionUpdate',@(src,evnt)obj.changedMotorPosition);
            
            %Initialize controller properties with set-access side-effects
            obj.motorStepSize = obj.motorStepSize;
            
        end
        
        function initialize(obj)
            initialize@most.Controller(obj);
            obj.motorUserPositionIndex = 1;
        end
        
        function exit(obj)
            obj.hModel.exit();
        end
        
        function ziniChannelControls(obj)
            %             handles = obj.hGUIData.channelControlsV4;
            %
            %             %Initialize Channel table PropControl
            %             hColArrayTable = most.gui.control.ColumnArrayTable(handles.tblChanConfig);
            %             handles.pcChannelConfig =  hColArrayTable;
            %             guidata(hSICtl.hGUIs.channelControlsV4,handles);
            %
            %             hColArrayTable.resize(obj.hModel.MAX_NUM_CHANNELS);
            
            obj.hGUIData.channelControlsV4.pcChannelConfig.resize(obj.hModel.MAX_NUM_CHANNELS);
            obj.hGUIData.channelControlsV4.channelImageHandler.initColorMapsInTable(); % re-init to deal with resize
            obj.hGUIData.channelControlsV4.channelImageHandler.registerChannelImageFigs(obj.hModel.hFigs);
        end
        
        function ziniFigPositions(obj)
            movegui(obj.hGUIs.mainControlsV4,'northwest');
            drawnow expose % otherwise the main gui is not always moved to the correct position
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4,obj.hGUIs.configControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4,obj.hGUIs.imageControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.configControlsV4,obj.hGUIs.channelControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.imageControlsV4,obj.hGUIs.powerControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.powerControlsV4,obj.hGUIs.motorControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);            
            most.gui.tetherGUIs(obj.hGUIs.motorControlsV4,obj.hGUIs.fastZControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);
            
            % stack channel display figures
            initialPosition = [700 300];
            offset = 30;
            numFigs = length(obj.hModel.hFigs);
            for i = 1:numFigs
                figNum = numFigs - i + 1;
                offset_ = offset * (i-1);
                position = [initialPosition(1)+offset_, initialPosition(2)-offset_];
                setpixelposition(obj.hModel.hFigs(figNum),[position(1,:) 408 408]);
                figure(figNum); % raise figure
            end
            setpixelposition(obj.hModel.hMergeFigs,[700 250 490 490]);     %Invisible by default
        
            % ensure no figure is located outside the visible part of the screen
            allFigs = [obj.hGUIsArray(:)' obj.hModel.hFigs(:)' obj.hModel.hMergeFigs(:)'];
            for hFig = allFigs
               most.gui.moveOntoScreen(hFig);
            end
        end
        
        function ziniRegisterFigs(obj)
            % makes channel windows 'managed' figures so that they are
            % saved in the user settings file
            for i = 1:numel(obj.hModel.hFigs)
                hFig = obj.hModel.hFigs(i);
                obj.registerGUI(hFig);
            end
            obj.registerGUI(obj.hModel.hMergeFigs);
        end
        
        function zcbkKeyPress(obj,~,evt)
            % Currently this handles keypresses for all SI5 guis
            switch evt.Key
                case {'f1' 'f2' 'f3' 'f4' 'f5' 'f6'}
                    idx = str2double(evt.Key(2));
                    
                    tfRequireCtrl = get(obj.hGUIData.fastConfigurationV4.cbRequireControl,'Value');
                    tfLoadFastCfg = ~tfRequireCtrl || ismember('control',evt.Modifier);
                    tfBypassAutoStart = ismember('shift',evt.Modifier);
                    
                    if tfLoadFastCfg
                        obj.hModel.fastCfgLoadConfig(idx,tfBypassAutoStart);
                    end
            end
        end
        
        function ziniSetKeyPressFcn(obj,handles)
            tags = fieldnames(handles);
            for c = 1:numel(tags)
                h = handles.(tags{c});
                if isprop(h,'KeyPressFcn')
                    set(h,'KeyPressFcn',@(src,evt)obj.zcbkKeyPress(src,evt));
                end
            end
        end
        
        function ziniMainControls(obj)
            
            %Disable controls for currently unimplemented features
            most.gui.disableAll(obj.hGUIData.mainControlsV4.pnlROIControls);
            
            disabledControls = {'stCycleIteration' 'stCycleIterationOf' ...
                'etIterationsDone' 'etIterationsTotal' ...
                'tbCycleControls' 'stScanRotation' 'scanRotation' ...
                'scanRotationSlider' 'zeroRotate' ...
                'stScanShiftFast' 'scanShiftSlow' 'scanShiftFast' ...
                'xstep' 'ystep' 'left' 'right' 'up' 'down' ...
                'centerOnSelection' 'zero' 'zoomhundredsslider' ...
                'zoomhundreds' 'etScanAngleMultiplierFast' 'pbLastLine' ...
                'pbLastLineParent' 'snapShot' 'numberOfFramesSnap' ...
                'pbBase' 'pbSetBase' 'pbRoot'};
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledControls);
            
            %Disable menu items for currently unimplemented features
            disabledMenuItems = {   'mnu_File_LoadCycle' 'mnu_File_SaveCycle' 'mnu_File_SaveCycleAs' ...
                'mnu_Settings_Beams' 'mnu_Settings_ExportedClocks' ...
                'mnu_View_CycleModeControls' 'mnu_View_ROIControls' 'mnu_View_PosnControls' ...
                'mnu_View_Channel1MaxDisplay' 'mnu_View_Channel2MaxDisplay' 'mnu_View_Channel3MaxDisplay' 'mnu_View_Channel4MaxDisplay'};
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledMenuItems);
            
            set(obj.hGUIData.mainControlsV4.figure1,'closeRequestFcn',@lclCloseEventHandler);
            
            function lclCloseEventHandler(src,evnt)
                ans = questdlg('Are you sure you want to exit ScanImage?','Exit ScanImage Confirmation','Yes','No','No');
                
                if strcmpi(ans,'No')
                    return; %Abort this exit function
                end
                obj.exit();
            end
        end
        
        function ziniConfigControls(obj)
            
            %Hide controls not used in SI5
            hideControls = {'tbShowAdvanced' 'pbApplyConfig' 'rbScanPhaseHardware'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Visible','off'), hideControls);
            
            %Disable controls with features not supported in SI5.1
            % disableControls = {'stShutterDelay' 'stShutterDelayMs' 'etShutterDelay'};
            disableControls = {'stShutterDelay' 'stShutterDelayMs' 'etShutterDelay' 'rbScanPhaseSoftware' };
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Enable','off'), disableControls);
            
            set(obj.hGUIData.configControlsV4.scanPhaseSlider,'Min',obj.hModel.scanPhaseRange(1),'Max',obj.hModel.scanPhaseRange(2),'SliderStep',[1/(obj.hModel.scanPhaseRange(2)-obj.hModel.scanPhaseRange(1)) 10/(obj.hModel.scanPhaseRange(2)-obj.hModel.scanPhaseRange(1))],'Value',0);
            
            %Tether default location to Main Controls (can later be overridden by user settings, if desired)
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4, obj.hGUIs.configControlsV4, 'righttop');
            
        end
        
        function ziniImageControls(obj)
            
            %Initialize menubars
            set(obj.hGUIData.imageControlsV4.mnu_Settings_AverageSamples,'Enable','off'); %Average samples option not available in SI5
            set(obj.hGUIData.imageControlsV4.mnuPMTOffsets,'Visible','off'); %Hide PMT offsets
            
            %Initialize channel LUT controls
            for i=1:obj.hModel.MAX_NUM_CHANNELS
                
                if i > obj.hModel.MAX_NUM_CHANNELS %Disable controls for reduced channel count devices
                    set(findobj(obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i)),'Type','uicontrol'),'Enable','off');
                    
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                    
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',i)),'String',num2str(0));
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',i)),'String',num2str(0));
                else
                    %Allow 10-percent of negative range, if applicable
                    chanLUTMin = obj.hModel.channelsLUTRange(1);
                    chanLUTMax = obj.hModel.channelsLUTRange(2);
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',chanLUTMin,'Max',chanLUTMax,'SliderStep',[.001 .05]);
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',chanLUTMin,'Max',chanLUTMax,'SliderStep',[.001 .05]);
                end
            end
            
            %Move Frame Averaging/Selection panel up if there are 2 or less channels
            if obj.hModel.MAX_NUM_CHANNELS <= 2
                
                charShift = (obj.hModel.MAX_NUM_CHANNELS - 2) * 5;
                
                for i=3:obj.hModel.MAX_NUM_CHANNELS
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Visible','off');
                    set(findall(hPnl),'Visible','off');
                end
                
                for i=1:2
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Position',get(hPnl,'Position') + [0 -charShift 0 0]);
                end
                
                %                 hPnl = obj.hGUIData.imageControlsV4.pnlAveragingAndSelection;
                %                 set(hPnl,'Position',get(hPnl,'Position') + [0 charShift 0 0]);
                %
                %                 hPnl = obj.hGUIData.imageControlsV4.pnlImageTools;
                %                 set(hPnl,'Position',get(hPnl,'Position') + [0 charShift 0 0]);
                
                hFig = obj.hGUIs.imageControlsV4;
                set(hFig,'Position',get(hFig,'Position') + [0 charShift 0 -charShift]);
                
            end
        end
        
        function ziniPowerControls(obj)
            %Disable features not currently supported
            set(obj.hGUIData.powerControlsV4.stPowerBox,'Enable','off');
            set(obj.hGUIData.powerControlsV4.tbShowPowerBox,'Enable','off');
            set(obj.hGUIData.powerControlsV4.cbDirectMode,'Enable','off'); 
            set(obj.hGUIData.powerControlsV4.cbLiveAdjust,'Enable','off');            
            
            
            if obj.hModel.beamNumBeams > 1
                set(obj.hGUIData.powerControlsV4.sldBeamIdx,'Max',obj.hModel.beamNumBeams,'Min',1);
                set(obj.hGUIData.powerControlsV4.sldBeamIdx,'SliderStep',[1 1]);
            else
                set(obj.hGUIData.powerControlsV4.sldBeamIdx,'Max',2,'Min',0,'Enable','off');
            end
            
            if obj.hModel.beamNumBeams
                znstConnectBeamPropToBeamControl('beamPowersDisplay',[findobj(obj.hGUIs.powerControlsV4,'Tag','etBeamPower');...
                    findobj(obj.hGUIs.powerControlsV4,'Tag','sldBeamPower')]);
                znstConnectBeamPropToBeamControl('beamPowerLimits',[findobj(obj.hGUIs.powerControlsV4,'Tag','etMaxLimit');...
                    findobj(obj.hGUIs.powerControlsV4,'Tag','sldMaxLimit')]);
                znstConnectBeamPropToBeamControl('beamLengthConstants',findobj(obj.hGUIs.powerControlsV4,'Tag','etZLengthConstant'));
                znstConnectBeamPropToBeamControl('beamPzAdjust',findobj(obj.hGUIs.powerControlsV4,'Tag','cbPzAdjust'));
                
                set(obj.hGUIData.powerControlsV4.pumBeamIdx,'Value',1);
                set(obj.hGUIData.powerControlsV4.sldBeamIdx,'Value',1);
                
                set(obj.hGUIData.powerControlsV4.pumBeamIdx,'String',obj.hModel.hBeams.beamIDs);
                
                %TODO: Review the following, copied from prior constructor code -- is this needed? why not handled via normal initialization mechanism?
                obj.changedBeamPowerUnits();
            else
                most.gui.disableAll(obj.hGUIs.powerControlsV4);
                obj.hideGUI('powerControlsV4');
            end
            
            %TODO: Support this 'dynamic' binding of control to a property as a Controller method OR support a Pcontrol for binding to array vals with display/control of 1 index at a time determined by an index control
            function znstConnectBeamPropToBeamControl(propName,hControls)
                obj.beamProp2Control.(propName) = hControls;
                set(hControls,'UserData',propName);
            end
        end
        
        function ziniMotorControls(obj)
            
            %Disable all if motor is disabled
            if ~obj.hModel.hMotors.motorHasMotor
                most.gui.disableAll(obj.hGUIs.motorControlsV4);
                obj.hideGUI(obj.hGUIs.motorControlsV4);
                return;
            end
            
            %Disable controls for features not supported in SI5
            disabledControls = {'etPosnID' 'stPosnID' 'pbAddCurrent' 'tbTogglePosn'};
            cellfun(@(s)set(obj.hGUIData.motorControlsV4.(s),'Enable','off'),disabledControls);
            
            if obj.hModel.hMotors.motorHasSecondMotor
                set(obj.hGUIData.motorControlsV4.pbZeroXY,'Visible','off');
                set(obj.hGUIData.motorControlsV4.pbZeroZ,'Visible','off');
                set(obj.hGUIData.motorControlsV4.pbAltZeroXY,'Visible','on');
                set(obj.hGUIData.motorControlsV4.pbAltZeroZ,'Visible','on');
                set(obj.hGUIData.motorControlsV4.cbSecZ,'Visible','on');
                set(obj.hGUIData.motorControlsV4.etPosZZ,'Visible','on');
                
                switch obj.hModel.motorDimensionConfiguration
                    case 'xyz-z'
                        set(obj.hGUIData.motorControlsV4.etPosZZ,'Enable','on');
                    otherwise
                        set(obj.hGUIData.motorControlsV4.etPosZZ,'Enable','off');
                end
            else
                set(obj.hGUIData.motorControlsV4.pbZeroXY,'Visible','on');
                set(obj.hGUIData.motorControlsV4.pbZeroZ,'Visible','on');
                set(obj.hGUIData.motorControlsV4.pbAltZeroXY,'Visible','off');
                set(obj.hGUIData.motorControlsV4.pbAltZeroZ,'Visible','off');
                set(obj.hGUIData.motorControlsV4.cbSecZ,'Visible','off');
                set(obj.hGUIData.motorControlsV4.etPosZZ,'Visible','off');
            end
            
            listnrs = obj.hModel.hMotors.hMotor.addlistener('LSCError',...
                @(src,evt)obj.motorErrorCbk(src,evt));
            if obj.hModel.hMotors.motorHasSecondMotor
                listnrs(end+1,1) = obj.hModel.hMotors.hMotorZ.addlistener('LSCError',...
                    @(src,evt)obj.motorErrorCbk(src,evt));
            end
            obj.motorErrorListeners = listnrs;
        end
        
        function ziniPosnControls(obj)
            % In SI5 Early, disable Position Control GUI until relative / absolute position handling is fixed.
            most.gui.disableAll(obj.hGUIs.posnControlsV4);
            
            %Disable all if motor is disabled
            %             if ~obj.hModel.hMotors.motorHasMotor
            %                 most.gui.disableAll(obj.hGUIs.posnControlsV4);
            %                 obj.hideGUI(obj.hGUIs.posnControlsV4);
            %                 return;
            %             end
            
            set(obj.hGUIData.posnControlsV4.sldPositionNumber,'Min',0);
            set(obj.hGUIData.posnControlsV4.sldPositionNumber,'Max',obj.motorMaxNumUserDefinedPositions);
            set(obj.hGUIData.posnControlsV4.sldPositionNumber,'SliderStep',[1/obj.motorMaxNumUserDefinedPositions 3/obj.motorMaxNumUserDefinedPositions]);
            set(obj.hGUIData.posnControlsV4.sldPositionNumber,'Value',0);
        end
        
        function ziniFastZControls(obj)
            if isempty(obj.hModel.hFastZ.hFastZ)
                most.gui.disableAll(obj.hGUIs.fastZControlsV4);
                obj.hideGUI(obj.hGUIs.fastZControlsV4);
            end
        end
        
        function ziniBScope2Controls(obj)
            if ~isempty(obj.hModel.hBScope2)
                if obj.hModel.hBScope2.lscInitSuccessful 
                    
                    if obj.hModel.hBScope2.hasRotation
                        disabledControls = {};
                    else
                        disabledControls = {'etRotationAngle' 'pbUpdateRotationAngle' 'pbResetLSC'...
                            'pbRotationAngle_Dec' 'etRotationAngleStepSize' 'pbRotationAngle_Inc'};
                    end
                else
                    disabledControls = {'pbGR_In' 'pbGR_Out' 'pbGG_In' 'pbGG_Out' 'pbPmt' 'pbCamera'...
                            'etRotationAngle' 'pbUpdateRotationAngle' 'pbResetLSC'...
                            'pbRotationAngle_Dec' 'etRotationAngleStepSize' 'pbRotationAngle_Inc'};
                end
                
                if ~obj.hModel.hBScope2.ecuInitSuccessful 
                    disabledControls{end+1} = 'etScanAlign';
                    disabledControls{end+1} = 'slScanAlign';
                end
                
                cellfun(@(s)set(obj.hGUIData.bScope2ControlsV5.(s),'Enable','off'),disabledControls);
            else
                most.gui.disableAll(obj.hGUIs.bScope2ControlsV5);
                obj.hideGUI(obj.hGUIs.bScope2ControlsV5);
            end
        end
        
        function ziniTriggers(obj)
	    
            terminalDisplayNames = obj.hModel.triggerExternalTerminalOptions;            
            %terminalDisplayNames = strrep(terminalDisplayNames,'/FPGA/',''); %Remove '/FPGA/' prefix   
            for i=1:length(terminalDisplayNames)
                if isempty(terminalDisplayNames{i})
                    terminalDisplayNames{i} = ' ';
                end
            end
	    
            set(obj.hGUIData.triggerControlsV5.tblTriggerConfig,'columnformat',{terminalDisplayNames, {'rising' 'falling'}});
            set(obj.hGUIData.triggerControlsV5.tblTriggerConfig,'columneditable',[true true]);
            terminalDisplayNames = {'Acquisition Start' 'Acquisition Stop' 'Next File Marker'};
            set(obj.hGUIData.triggerControlsV5.tblTriggerConfig,'RowName',terminalDisplayNames);
        end
        
        function ziniPmtControls(obj)
            numPmts = obj.hModel.hPMTs.numInstances;
            if numPmts <= 0
                most.gui.disableAll(obj.hGUIs.pmtControlsV5);
                obj.hideGUI(obj.hGUIs.pmtControlsV5);
            else
                %Leaving pmt names general for now
%                 for i = 1:numPmts
%                     stTag = sprintf('stPmt%d',i);
%                     pmtName = obj.hModel.hPMTs.names{i};
%                     set(obj.hGUIData.pmtControlsV5.(stTag),'String',pmtName);
%                 end
                
                for i = numPmts+1:4                    
                    pbTag = sprintf('pbPmt%dPower',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                    
                    etTag = sprintf('etPmt%dGain',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'Enable','off');
                    
                    pbTag = sprintf('etPmt%dStatus',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                    
                    pbTag = sprintf('pbResetPmt%d',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                end
            end
        end
        
        function ziniUsrSettingsGUI(obj)
            availableUsrProps = obj.hModel.USR_AVAILABLE_USR_PROP_LIST;
            
            % Throw a warning if any available user prop is not
            % SetObservable. This can happen b/c SetObservable-ness of usr
            % properties is required neither by the Model:mdlConfig
            % infrastructure nor by SI5 (this is arguably the right
            % thing to do). Meanwhile, the userSettings GUI provides a view
            % (via a propTable) into the current usrProps; this is
            % implemented via listeners. (Side note: ML silently allows
            % adding a listener to an obj for a prop that is not
            % SetObservable.)
            %
            % At the moment I believe all available usr props for SI3/4 are
            % indeed SetObservable, but this warning will be good for
            % maintenance moving forward.
            modelMC = metaclass(obj.hModel);
            metaprops = modelMC.Properties;
            allpropnames = cellfun(@(x)x.Name,metaprops,'UniformOutput',false);
            [tf loc] = ismember(availableUsrProps,allpropnames);
            assert(all(tf));
            usrMetaProps = metaprops(loc);
            tfSetObservable = cellfun(@(x)x.SetObservable,usrMetaProps);
            if any(~tfSetObservable)
                warning('SI5Controller:nonSetObservableUsrProp',...
                    'One or more available user properties is not SetObservable. The userSettings property table will not update for any such property.');
            end
            
            data(:,1) = sort(availableUsrProps);
            data(:,2) = {false}; % will get initted below
            set(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data',data);
            obj.changedUsrPropListCurrent();
        end
        
    end
    
    %% PRIVATE/PROTECTED PROPERTIES
    properties (Hidden)
        motorUserPositionIndex;
        motorStepSize = [0.1 0.1 0.1]; %Step size to use, in um, for motor increment/decrement operations in X,Y,Z axes. Z axis value pertains to active Z controller, if secondary is present.
        motorErrorListeners = [];
        
        bScope2RotationAngleStepSize = 0.1;
    end
    
    properties (Constant,Hidden)
        motorMaxNumUserDefinedPositions = 100;
        WINDOW_BORDER_SPACING = 10; % [pixels] space between tethered guis
    end
    
    %% PROPERTY ACCESS
    methods
        function val = get.hMainPbFastCfg(obj)
            val = [obj.hGUIData.mainControlsV4.pbFastConfig1; ...
                obj.hGUIData.mainControlsV4.pbFastConfig2; ...
                obj.hGUIData.mainControlsV4.pbFastConfig3; ...
                obj.hGUIData.mainControlsV4.pbFastConfig4; ...
                obj.hGUIData.mainControlsV4.pbFastConfig5; ...
                obj.hGUIData.mainControlsV4.pbFastConfig6];
        end
        
        % This sets the GUI-displayed status string, NOT the hModel status
        % string.
        function set.mainControlsStatusString(obj,val)
            set(obj.hGUIData.mainControlsV4.statusString,'String',val);
        end
        
        % This gets the GUI-displayed status string, NOT the hModel status
        % string.
        function val = get.mainControlsStatusString(obj)
            val = get(obj.hGUIData.mainControlsV4.statusString,'String');
        end
        
        %% Beams
        function set.beamDisplayIdx(obj,val)
            if obj.hModel.beamNumBeams <= 0
                return;
            end
            
            assert(ismember(val,1:obj.hModel.beamNumBeams));
            if val~=obj.beamDisplayIdx
                obj.beamDisplayIdx = val;
                beamPropNames = fieldnames(obj.beamProp2Control); %#ok<MCSUP>
                for i = 1:numel(beamPropNames)
                    %propName = obj.beamProp2Control.(beamPropNames{i}); %#ok<MCSUP>
                    %propName
                    %obj.changedBeamParams(propName);
                    obj.changedBeamParams(beamPropNames{i});
                end
                set(obj.hGUIData.powerControlsV4.pumBeamIdx,'Value',val); %#ok<*MCSUP>
                set(obj.hGUIData.powerControlsV4.sldBeamIdx,'Value',val);
            end
        end
        
        %% Motors
        
        function set.motorStepSize(obj,val)
            
            currVal = obj.motorStepSize;
            assert(numel(val) == numel(currVal),'The motorStepSize value must have %d elements',numel(currVal));
            
            %Only change dimensions with valid values (positive, finite, smaller than fastMotionThreshold)
            val(val <= 0 | val > obj.hModel.hMotors.motorFastMotionThreshold | isinf(val)) = nan;
            unchangedDims = isnan(val);
            val(unchangedDims) = currVal(unchangedDims);
            
            %Set property & update view
            obj.motorStepSize = val;
            
            set(obj.hGUIData.motorControlsV4.etStepSizeX,'String',num2str(val(1),'%0.5g'));
            set(obj.hGUIData.motorControlsV4.etStepSizeY,'String',num2str(val(2),'%0.5g'));
            set(obj.hGUIData.motorControlsV4.etStepSizeZ,'String',num2str(val(3),'%0.5g'));
            
        end
        
        function set.motorUserPositionIndex(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative' 'scalar' 'integer'});
            if val > obj.motorMaxNumUserDefinedPositions
                val = obj.motorMaxNumUserDefinedPositions;
            end
            
            obj.motorUserPositionIndex = val;
            if val==0
                set(obj.hGUIData.posnControlsV4.etPositionNumber,'String','');
            else
                set(obj.hGUIData.posnControlsV4.etPositionNumber,'String',num2str(val));
            end
            set(obj.hGUIData.posnControlsV4.sldPositionNumber,'Value',val);
        end
        
        
        %% BScope2
        
        function set.bScope2RotationAngleStepSize(obj, val)
            %Only change dimensions with valid values
            if numel(val) == 1
                if ~(val <= 0 || val > 10 || isnan(val))
                    obj.bScope2RotationAngleStepSize = val;
                end
            end
            
            val = obj.bScope2RotationAngleStepSize;
            set(obj.hGUIData.bScope2ControlsV5.etRotationAngleStepSize,'String',num2str(val,'%0.5g'));
        end
        
    end
    
    %% APP PROPERTY CALLBACKS
    % Methods named changedXXX(src,...) respond to changes to model, which should update the controller/GUI
    % Methods named changeXXX(hObject,...) respond to changes to GUI, which should update the model
    methods
        %% TIMER METHODS
        function changedSecondsCounter(obj,~,~)
            %TODO: make value of 0 'sticky' for 0.3-0.4s using a timer object here
            hSecCntr = obj.hGUIData.mainControlsV4.secondsCounter;
            
            switch obj.hModel.secondsCounterMode
                case 'up' %countup timer
                    set(hSecCntr,'String',num2str(max(0,floor(obj.hModel.secondsCounter))));
                case 'down'  %countdown timer
                    set(hSecCntr,'String',num2str(max(0,ceil(obj.hModel.secondsCounter))));
                otherwise
                    set(hSecCntr,'String','0');
            end
        end
        
        %% DISPLAY METHODS
        function changedDisplayRollingAverageFactorLock(obj,~,~)
            if obj.hModel.displayRollingAverageFactorLock
                set(obj.hGUIData.imageControlsV4.etRollingAverage,'Enable','off');
            else
                set(obj.hGUIData.imageControlsV4.etRollingAverage,'Enable','on');
            end
        end
        
        function changedDisplayFrameBatchSelectLast(obj,~,~)
            if obj.hModel.displayFrameBatchSelectLast
                set(obj.hGUIData.imageControlsV4.etFrameSelections,'Enable','off');
            else
                set(obj.hGUIData.imageControlsV4.etFrameSelections,'Enable','on');
            end
        end
        
        function changedDisplayFrameBatchFactorLock(obj,~,~)
            if obj.hModel.displayFrameBatchFactorLock
                set(obj.hGUIData.imageControlsV4.etFrameSelFactor,'Enable','off');
            else
                set(obj.hGUIData.imageControlsV4.etFrameSelFactor,'Enable','on');
            end
        end
        
        %% BEAM METHODS
        function changeBeamParams(obj,src,~,~)
            %Change occurred to beam-indexed params in view/controller
            
            switch get(src,'Style')
                case 'edit'
                    newVal = str2double(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                otherwise
                    assert(false,'Unsupported control style.');
            end
            propName = get(src,'UserData');
            
            try
                obj.hModel.(propName)(obj.beamDisplayIdx) = newVal;
            catch ME
                % Error setting beam-indexed model prop; revert GUI
                obj.changedBeamParams(propName);
                
                % TODO what is the right thing here
                switch ME.identifier
                    % currently don't throw any warnings/errs
                end
            end
            
        end
        
        function changeBeamPowersDisplay(obj,src,~,~)
            if obj.hModel.beamNumBeams <= 0
                return;
            end
            
            switch get(src,'Style')
                case 'edit'
                    newVal = str2double(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                otherwise
                    assert(false,'Unsupported control style.');
            end
            
            try
                obj.hModel.hBeams.beamPowers(obj.beamDisplayIdx) = newVal;
            catch ME
                switch ME.identifier
                    % currently don't throw any warnings/errs
                end
            end
        end
        
        function changedBeamPowersDisplay(obj,src,evnt)
            %Do nothing.
        end
        
        function changedBeamParams(obj,src,evnt)
            %Change occurred to beam-indexed property in model; refresh
            % controls tied to that prop.
            % src: either a meta.prop object (when changedBeamParams used as
            % prop listener), or a propName string
            
            if obj.hModel.beamNumBeams <= 0
                return;
            end
            
            if ischar(src)
                propName = src;
            elseif isa(src,'meta.property')
                propName = src.Name;
            else
                assert(false,'Invalid src input arg.');
            end
            
            newVal = obj.hModel.(propName)(obj.beamDisplayIdx);
            
            hControls = obj.beamProp2Control.(propName);
            for c = 1:numel(hControls)
                switch get(hControls(c),'Style')
                    case 'edit'
                        set(hControls(c),'String',num2str(newVal));
                    case 'slider'
                        set(hControls(c),'Value',newVal);
                    case 'checkbox'
                        set(hControls(c),'Value',newVal);
                    otherwise
                        assert(false,'Unsupported control style.');
                end
            end
        end
        
        function changedBeamPowerUnits(obj,src,evnt) %#ok<*INUSD>
            switch obj.hModel.beamPowerUnits
                case 'percent'
                    set(obj.hGUIData.powerControlsV4.rbPercentBeamPower,'Value',1);
                    set(obj.hGUIData.powerControlsV4.rbMilliwattBeamPower,'Value',0);
                case 'milliwatts'
                    set(obj.hGUIData.powerControlsV4.rbPercentBeamPower,'Value',0);
                    set(obj.hGUIData.powerControlsV4.rbMilliwattBeamPower,'Value',1);
                otherwise
                    assert(false,'Unsupported value of beamPowerUnits.');
            end
        end
        
        function changedBeamPzAdjust(obj,src,evnt)
            if obj.hModel.beamNumBeams <= 0
                return;
            end
            
            currBeamActive = obj.hModel.beamPzAdjust(obj.beamDisplayIdx);
            
            set(obj.hGUIData.powerControlsV4.cbPzAdjust,'Value',currBeamActive);
            
            if currBeamActive
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','on');
            else
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off');
            end
        end
        
        %% Trigger Methods
        function changeTriggerDialogData(obj,src,evnt)
            if ~strcmp(obj.hModel.acqState,'idle')
                obj.changedTriggerDialogData(); %reset changes
                error('Cannot change trigger configuration during an active acquisition');
            end
            
            %triggersConfigured = false;
            data = get(src,'Data');
            %triggerEdited = evnt.NewData
            rowedited = evnt.Indices(1);
            %             newTrigger = data{rowedited,1}
            %newEdge = data{rowedited,2};
            if strcmp(data{rowedited,1},' ')
                data{rowedited,2} = 'rising'; %Clear old edge type if clearing trigger.
            end
            
            for rowindex = 1:size(data,1)
                terminals = data{rowindex,1};
                terminals = strrep(terminals,' ',''); 
                obj.hModel.triggerExternalTerminals{rowindex} = terminals;
                obj.hModel.triggerExternalEdges{rowindex} = data{rowindex,2};
            end
        end
        
        function changedTriggerDialogData(obj,src,evnt)
            
            %Update trigger dialog table data
            data = cell(3,2);
            for rowindex = 1:numel(obj.hModel.triggerExternalTypes)
                data{rowindex,1} = obj.hModel.triggerExternalTerminals{rowindex};
                data{rowindex,2} = obj.hModel.triggerExternalEdges{rowindex};
            end
            
            set(obj.hGUIData.triggerControlsV5.tblTriggerConfig,'Data',data);
            
            %Handle change to triggerExternalAvailable
            if obj.hModel.triggerExternalAvailable
                triggerButtonEnable = 'on';
            else
                triggerButtonEnable = 'off';
            end
            set(obj.hGUIData.mainControlsV4.tbExternalTrig,'Enable',triggerButtonEnable);
            
        end
        
        %         function changedTriggerExternalAvailable(obj,src,evnt)
        %             if obj.hModel.triggerExternalAvailable
        %                 triggerButtonEnable = 'on';
        %             else
        %                 triggerButtonEnable = 'off';
        %             end
        %             set(obj.hGUIData.mainControlsV4.tbExternalTrig,'Enable',triggerButtonEnable);
        %         end
        
        %% SI4.2 CHANNEL METHODS
        function changeGUIToggleToolState(obj,src,guiToolFcn)
            if get(src,'Value');
                
                % Untoggle other togglebuttons
                switch get(src,'Tag')
                    case 'tbZoom'
                        set(obj.hGUIData.imageControlsV4.tbDataTip,'Value',false);
                    case 'tbDataTip'
                        set(obj.hGUIData.imageControlsV4.tbZoom,'Value',false);
                    otherwise
                        assert(false);
                end
                
                % Get target figure
                hFig = obj.zzzSelectImageFigure();
                if isempty(hFig)
                    set(src,'Value',false); % revert
                    return;
                end
                
                guiToolFcn(hFig,'on');
            else
                %TODO: Include merge figure
                for i=1:numel(obj.hModel.channelsDisplay)
                    activeChan = obj.hModel.channelsDisplay(i);
                    arrayfun(@(hIm)guiToolFcn(ancestor(hIm,'figure'),'off'),obj.hModel.hImages{activeChan});
                    guiToolFcn(ancestor(obj.hModel.hMergeFigs,'figure'),'off');
                end
            end
        end
        
        function changedChannelsMergeEnable(obj,src,evt)
            val = obj.hModel.channelsMergeEnable;
            if val
                set(obj.hGUIData.channelControlsV4.cbChannelsMergeFocusOnly,'Enable','on');
            else
                set(obj.hGUIData.channelControlsV4.cbChannelsMergeFocusOnly,'Enable','off');
            end
        end
        
        %% SI5 CHANNEL METHODS
        function changedChanLUT(obj,src,evnt)
            %Cycle through and update all chanLUT properties
            for i=1:obj.hModel.MAX_NUM_CHANNELS
                chanProp = sprintf('chan%dLUT',i);
                
                blackVal = obj.hModel.(chanProp)(1);
                whiteVal = obj.hModel.(chanProp)(2);
                
                set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Value',blackVal);
                set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Value',whiteVal);
                
                set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',i)),'String',num2str(blackVal));
                set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',i)),'String',num2str(whiteVal));
            end
        end
        
        function changeChannelsLUT(obj,src,blackOrWhite,chanIdx)
            %blackOrWhite: 0 if black, 1 if white
            %chanIdx: Index of channel whose LUT value to change
            
            switch get(src,'Style')
                case 'edit'
                    newVal = str2num(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                    newVal = round(newVal); %Only support integer values, from slider controls
            end
            
            if isempty(newVal) %Erroneous entry
                obj.changedChanLUT(); %refresh View
            else
                chanProp = sprintf('chan%dLUT',chanIdx);
                %Force black level to be less than white level
                if ~blackOrWhite %set black level
                    if newVal >= obj.hModel.(chanProp)(2)
                        newVal = obj.hModel.(chanProp)(2) - 1;
                    end
                else %set white level
                    if newVal <= obj.hModel.(chanProp)(1)
                        newVal = obj.hModel.(chanProp)(1) + 1;
                    end
                end
                
                %Perform upper/lower bounds check.
                if newVal < obj.hModel.channelsLUTRange(1)
                    newVal = obj.hModel.channelsLUTRange(1);
                elseif newVal > obj.hModel.channelsLUTRange(2)
                    newVal = obj.hModel.channelsLUTRange(2);
                end
                
                try
                    obj.hModel.(chanProp)(2^blackOrWhite) = newVal;
                catch ME
                    obj.changedChanLUT();
                    obj.updateModelErrorFcn(ME);
                end
            end
            
        end
        
        function changedAcqFramesDone(obj,src,evnt)
            switch obj.hModel.acqState
                case 'focus'
                    %do nothing
                otherwise
                    val = obj.hModel.acqFramesDone;
                    set(obj.hGUIData.mainControlsV4.framesDone,'String',num2str(val));
            end
        end
        
        function changedAcqState(obj,src,evnt)
            hFocus = obj.hGUIData.mainControlsV4.focusButton;
            hGrab = obj.hGUIData.mainControlsV4.grabOneButton;
            hLoop = obj.hGUIData.mainControlsV4.startLoopButton;
            switch obj.hModel.acqState
                case 'idle'
                    set(hFocus,'String','FOCUS','Visible','on');
                    set(hGrab,'String','GRAB','Visible','on');
                    set(hLoop,'String','LOOP','Visible','on');
                    
                case 'focus'
                    set([hFocus hGrab hLoop],'Visible','off');
                    set(hFocus,'String','ABORT','Visible','on');
                    
                case 'grab'
                    set([hFocus hGrab hLoop],'Visible','off');
                    set(hGrab,'String','ABORT','Visible','on');
                    
                case {'loop' 'loop_wait'}
                    set([hFocus hGrab hLoop],'Visible','off');
                    set(hLoop,'String','ABORT','Visible','on');
                    
                    %TODO: Maybe add 'error' state??
                    
            end
        end
        
        function changedScanAngleMultiplierSlow(obj,~,~)
            
            s = obj.hGUIData.configControlsV4;
            hForceSquareCtls = [s.cbForceSquarePixel s.cbForceSquarePixelation];
            
            if obj.hModel.scanAngleMultiplierSlow == 0
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',1);
                set(hForceSquareCtls,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',0);
                set(hForceSquareCtls,'Enable','on');
            end
        end
        
        function changeScanPhaseSlider(obj,src)
            obj.hModel.scanPhaseChanged = true;
            obj.hModel.periodClockPhase = get(src,'Value');
            set(src,'Value',obj.hModel.periodClockPhase)
        end
        
        function changedScanPhase(obj,~,~)
            obj.hModel.scanPhaseChanged = true;
            set(obj.hGUIData.configControlsV4.scanPhaseSlider,'Value',obj.hModel.periodClockPhase);
        end
        
        function changeScanPhaseStepwise(obj,stepMultiplier,fineStep)
            if fineStep
                step = 1;
            else
                step = 4;
            end
            value = obj.hModel.periodClockPhase + step*stepMultiplier;
            obj.hModel.periodClockPhase = value;
        end
        
        function changedScanFramePeriod(obj,~,~)
            if isnan(obj.hModel.scanFramePeriod)
                set(obj.hGUIData.fastZControlsV4.etFramePeriod,'BackgroundColor',[0.9 0 0]);
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',[0.9 0 0]);
            else
                set(obj.hGUIData.fastZControlsV4.etFramePeriod,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
            end
        end
        
        function changedScanForceSquarePixelation_(obj,~,~)
            if obj.hModel.scanForceSquarePixelation_
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','inactive');
                %Update linesPerFrame to equal pixelsPerLine if we are
                %enforcing square pixelation and the linesPerFrame does not
                %already equal pixelsPerLine.
                if obj.hModel.linesPerFrame ~= obj.hModel.pixelsPerLine
                    obj.hModel.linesPerFrame = obj.hModel.pixelsPerLine;
                end
            else
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','on');
            end
        end
        
        function changedForceSquarePixels(obj,~,~)
            % This function should only change the aspect ratio of the
            % display, not affect the ability for the user to change the
            % scan angle multiplier.
            obj.changedImageAspectRatio();
        end
        
        function changedImageAspectRatio(obj,~,~)
            obj.hModel.zprpSetPixelationProp('scanAngleMultiplier');
        end
        
        function changeScanZoomFactor(obj,hObject,absIncrement,lastVal)
            %hLSM = obj.hModel.hLSM;
            newVal = get(hObject,'Value');
            
            currentZoom = obj.hModel.zoomFactor;
            
            if newVal > lastVal
                if currentZoom + absIncrement > 99.9
                    newZoom = 99.9;
                else
                    newZoom = currentZoom + absIncrement;
                end
            elseif newVal < lastVal
                if currentZoom - absIncrement < 1
                    newZoom = 1;
                else
                    newZoom = currentZoom - absIncrement;
                end
            else
                newZoom = currentZoom;
            end
            
            obj.hModel.zoomFactor  = newZoom;
        end
        
        function changedStatusString(obj,~,~)
            % For now, just display the string
            ss = obj.hModel.statusString;
            obj.mainControlsStatusString = ss;
        end
        %{
[ ] FIXME Need to figure out the right things to listen to to toggle this.

function changedTriggerExtTrigAvailable(obj,~,~)
            hBtn = obj.hGUIData.mainControlsV4.tbExternalTrig;
            if obj.hModel.triggerExtTrigAvailable
                set(hBtn,'Enable','on');
            else
                set(hBtn,'Enable','off');
            end
        end
        %}
        
        function changedFastZSettlingTime(obj,~,~)
            hFastZGUI = obj.hGUIData.fastZControlsV4;
            
            switch obj.hModel.fastZScanType
                case 'sawtooth'
                    set(hFastZGUI.etSettlingTime,'String',num2str(obj.hModel.fastZAcquisitionDelay));
                case 'step'
                    set(hFastZGUI.etSettlingTime,'String',num2str(obj.hModel.fastZSettlingTime));
                otherwise
                    assert(false);
            end
        end
        
        function changeFastZSettlingTimeVar(obj,src,~,~)
            
            val = str2double(get(src,'String'));
            if isnan(val)
                obj.changedFastZSettlingTime();
                return;
            end
            
            try
                switch obj.hModel.fastZScanType
                    case 'sawtooth'
                        obj.hModel.fastZAcquisitionDelay = val;
                    case 'step'
                        obj.hModel.fastZSettlingTime = val;
                    otherwise
                        assert(false);
                end
            catch ME
                obj.changedFastZSettlingTime();
                switch ME.identifier
                    case 'most:InvalidPropVal'
                        % no-op
                    case 'PDEPProp:SetError'
                        throwAsCaller(obj.DException('','ModelUpdateError',ME.message));
                    otherwise
                        ME.rethrow();
                end
            end
            
        end
        
        function changedLoggingEnable(obj,~,~)
            
            hAutoSaveCBs = [obj.hGUIData.mainControlsV4.cbAutoSave obj.hGUIData.configControlsV4.cbAutoSave];
            hLoggingControls = [obj.hGUIData.mainControlsV4.baseName obj.hGUIData.mainControlsV4.baseNameLabel ...
                obj.hGUIData.mainControlsV4.fileCounter obj.hGUIData.mainControlsV4.fileCounterLabel];
            
            if obj.hModel.loggingEnable
                set(hAutoSaveCBs,'BackgroundColor',[0 .8 0]);
                set(hLoggingControls,'Enable','on');
            else
                set(hAutoSaveCBs,'BackgroundColor',[1 0 0]);
                set(hLoggingControls,'Enable','off');
            end
        end
        
        function setSavePath(obj,~,~)
            folder_name = uigetdir(pwd);
            
            if folder_name ~= 0
                obj.hModel.loggingFilePath = folder_name;
            end
        end
        
        %% CFG CONFIG %%
        function changedCfgFilename(obj,~,~)
            cfgFilename = obj.hModel.cfgFilename;
            [~,fname] = fileparts(cfgFilename);
            set([obj.hGUIData.mainControlsV4.configName obj.hGUIData.configControlsV4.configurationName],'String',fname);
        end
        
        %% FASTCFG %%
        function changedFastCfgCfgFilenames(obj,~,~)
            fastCfgFNames = obj.hModel.fastCfgCfgFilenames;
            tfEmpty = cellfun(@isempty,fastCfgFNames);
            set(obj.hMainPbFastCfg(tfEmpty),'Enable','off');
            set(obj.hMainPbFastCfg(~tfEmpty),'Enable','on');
        end
        
        function changedFastCfgAutoStartTf(obj,~,~)
            autoStartTf = obj.hModel.fastCfgAutoStartTf;
            defaultBackgroundColor = get(0,'defaultUicontrolBackgroundColor');
            set(obj.hMainPbFastCfg(autoStartTf),'BackGroundColor',[0 1 0]);
            set(obj.hMainPbFastCfg(~autoStartTf),'BackGroundColor',defaultBackgroundColor);
        end
        
        %% USR CONFIG %%
        function changedUsrFilename(obj,~,~)
            usrFilename = obj.hModel.usrFilename;
            [~,fname] = fileparts(usrFilename);
            set(obj.hGUIData.mainControlsV4.userSettingsName,'String',fname);
        end
        
        function changedUsrPropListCurrent(obj,~,~)
            usrPropSubsetCurrent = obj.hModel.usrPropListCurrent;
            NUsrPropSubsetCurrent = numel(usrPropSubsetCurrent);
            
            % remove previous listeners for userSettingsV4
            delete(obj.usrSettingsPropListeners);
            
            % add new listeners
            listenerObjs = event.proplistener.empty(0,1);
            for c = 1:NUsrPropSubsetCurrent
                pname = usrPropSubsetCurrent{c};
                listenerObjs(c) = obj.hModel.addlistener(pname,'PostSet',@obj.changedCurrentUsrProp);
            end
            obj.usrSettingsPropListeners = listenerObjs;
            
            % Update currentUsrProps table to use new property subset
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.reset();
            formatStruct = struct('format','char','info',[]); % xxx explain char
            formatCell = num2cell(repmat(formatStruct,NUsrPropSubsetCurrent,1));
            metadata = cell2struct(formatCell,usrPropSubsetCurrent,1);
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.addProps(metadata);
            
            % Manually fire listeners for each prop in usrPropSubsetCurrent
            % so that the currentUsrProps table updates
            for c = 1:NUsrPropSubsetCurrent
                pname = usrPropSubsetCurrent{c};
                obj.changedCurrentUsrProp(pname);
            end
            
            % Update specifyCurrentUsrProps table
            data = get(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data');
            availableUsrProps = data(:,1);
            tfInCurrentUsrSubset = ismember(availableUsrProps,usrPropSubsetCurrent);
            data(:,2) = num2cell(tfInCurrentUsrSubset);
            set(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data',data);
        end
        
        % changedCurrentUsrProp(obj,src,evt)
        % changedCurrentUsrProp(obj,propName)
        function changedCurrentUsrProp(obj,varargin)
            switch nargin
                case 2
                    propName = varargin{1};
                case 3
                    src = varargin{1};
                    propName = src.Name;
                otherwise
                    assert(false,'Invalid number of args.');
            end
            val = obj.hModel.(propName);
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.encodeFcn(propName,val);
        end
        
        % This looks similar to Controller.updateModel for PropControls.
        % However updateModel() does not quite work as when there is a
        % failure, it reverts using Controller.updateViewHidden. This will
        % not work as the currentUsrProps are not currently participating
        % in the prop2Control struct business.
        function changeCurrentUsrProp(obj,hObject,eventdata,handles)
            [status propName propVal] = ...
                obj.hGUIData.userSettingsV4.pcCurrentUSRProps.decodeFcn(hObject,eventdata,handles);
            switch status
                case 'set'
                    try
                        obj.hModel.(propName) = propVal;
                    catch ME
                        obj.changedCurrentUsrProp(propName);
                        switch ME.identifier
                            case 'most:InvalidPropVal'
                                % no-op
                            case 'PDEPProp:SetError'
                                throwAsCaller(obj.DException('','ModelUpdateError',ME.message));
                            otherwise
                                ME.rethrow();
                        end
                    end
                case 'revert'
                    obj.changedCurrentUsrProp(propName);
                otherwise
                    assert(false);
            end
        end
        
        function specifyCurrentUsrProp(obj,hObject,eventdata,handles)
            data = get(hObject,'data');
            availableUsrProps = data(:,1);
            tf = cell2mat(data(:,2));
            obj.hModel.usrPropListCurrent = availableUsrProps(tf);
        end
        
        %% MOTOR %%
        function changeMotorPosition(obj,src,coordinateIdx)
            newVal = str2double(get(src,'String'));
            try
                %NOTE: Indexing operation forces read of motorPosition prior to setting
                obj.hModel.motorPosition(coordinateIdx) = newVal;
            catch %#ok<CTCH>
                obj.changedMotorPosition(); % refreshes motor-Position-related GUI components
            end
        end
        
        % changedMotorPosition(obj,src,evt) - used as callback
        % changedMotorPosition(obj,tfUseLast)
        % changedMotorPosition(obj)
        function changedMotorPosition(obj,~,~)
            
            formatStr = '%.2f';
            
            motorPos = obj.hModel.motorPosition;
            if ~isempty(motorPos)
                set(obj.hGUIData.motorControlsV4.etPosX,'String',num2str(motorPos(1),formatStr));
                set(obj.hGUIData.motorControlsV4.etPosY,'String',num2str(motorPos(2),formatStr));
                set(obj.hGUIData.motorControlsV4.etPosZ,'String',num2str(motorPos(3),formatStr));
                set(obj.hGUIData.motorControlsV4.etPosR,'String',num2str(norm(motorPos(1:3)),formatStr));
                if numel(motorPos)==4
                    set(obj.hGUIData.motorControlsV4.etPosZZ,'String',num2str(motorPos(4),formatStr));
                end
            end
        end
        
        function changedStackStartEndPositionPower(obj,~,~)
            startPos = obj.hModel.stackZStartPos;
            endPos = obj.hModel.stackZEndPos;
            startPower = obj.hModel.stackStartPower; % todo multibeam
            endPower = obj.hModel.stackEndPower; % todo multibeam
            
            set(obj.hGUIData.motorControlsV4.etStartPower,'String',num2str(startPower));
            set(obj.hGUIData.motorControlsV4.etEndPower,'String',num2str(endPower));
            
            if obj.hModel.fastZEnable
                hStartEndCtls = {'etStackStart' 'etStackEnd'};
                cellfun(@(x)set(obj.hGUIData.motorControlsV4.(x),'Enable','off'),hStartEndCtls);
            else
                zlclEnableUIControlBasedOnVal(obj.hGUIData.motorControlsV4.etStackStart,startPos,'inactive');
                zlclEnableUIControlBasedOnVal(obj.hGUIData.motorControlsV4.etStackEnd,endPos,'inactive');
            end
            
            if ~isnan(startPower)
                set(obj.hGUIData.motorControlsV4.cbUseStartPower,'Enable','on');
            else
                obj.hModel.stackUseStartPower = false;
                set(obj.hGUIData.motorControlsV4.cbUseStartPower,'Enable','off');
            end
            
            if obj.hModel.stackStartEndPointsDefined && obj.hModel.hBeams.stackStartEndPowersDefined
                set(obj.hGUIData.motorControlsV4.cbOverrideLz,'Enable','on');
                set(obj.hGUIData.motorControlsV4.pbOverrideLz,'Enable','on');
            else
                obj.hModel.stackUserOverrideLz = false;
                set(obj.hGUIData.motorControlsV4.cbOverrideLz,'Enable','off');
                set(obj.hGUIData.motorControlsV4.pbOverrideLz,'Enable','off');
            end
        end
        
        function changedStackUseStartPower(obj,~,~)
            tfUseStartPower = obj.hModel.stackUseStartPower;
            if tfUseStartPower && ~obj.hModel.fastZEnable
                set(obj.hGUIData.motorControlsV4.etStartPower,'Enable','inactive');
            else
                set(obj.hGUIData.motorControlsV4.etStartPower,'Enable','off');
            end
        end
        
        %% FAST Z %%
        function changedFastZDiscardFlybackFrames(obj,~,~)
            hFastZGUI = obj.hGUIData.fastZControlsV4;
            
            if obj.hModel.fastZDiscardFlybackFrames
                set(hFastZGUI.etNumDiscardFrames,'Enable','inactive');
            else
                set(hFastZGUI.etNumDiscardFrames,'Enable','off');
            end
        end
        
        function changedOverrideLz(obj,~,~)
            tf = obj.hModel.stackUserOverrideLz;
            if tf && ~obj.hModel.fastZEnable
                set(obj.hGUIData.motorControlsV4.etEndPower,'Enable','inactive');
            else
                set(obj.hGUIData.motorControlsV4.etEndPower,'Enable','off');
            end
        end
        
        function changedFastZEnable(obj,~,~)
            obj.changedStackStartEndPositionPower();
            obj.changedStackUseStartPower();
            obj.changedOverrideLz();
            if obj.hModel.fastZEnable
                obj.hModel.acqNumFrames = 1;
                set(obj.hGUIData.mainControlsV4.framesTotal,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.framesTotal,'Enable','on');
            end
        end
        
        function changedFastZScanType(obj,~,~)
            hFastZGUI = obj.hGUIData.fastZControlsV4;
            
            switch lower(obj.hModel.fastZScanType)
                case 'sawtooth'
                    set(hFastZGUI.stSettlingTime,'String','Acq Delay');
                case 'step'
                    set(hFastZGUI.stSettlingTime,'String','Settling Time');
                otherwise
                    assert(false);
            end
            
            obj.changedFastZSettlingTime();
        end
        %% Main Controls
        function changedPointButton(obj,src,~)
            if get(src,'Value')
                obj.hModel.scanPointBeam();
                set(src,'String','PARK','ForegroundColor','r');
            else
                obj.hModel.abort();
                set(src,'String','POINT','ForegroundColor',[0 .6 0]);
            end
        end
        
        %% Override Methods
        function showAllGUIs(obj)
            %HACK to prevent unsupported GUIs from being shown
            
            managedGUIs = setdiff(obj.hManagedGUIs,obj.hGUIs.posnControlsV4);
            arrayfun(@(x)obj.showGUI(x),managedGUIs);
        end
       
    end
    
    %% ACTION CALLBACKS
    methods (Hidden)
        %% BEAM FUNCTION CALLBACKS
        function calibrateBeam(obj)
            beamIdx = obj.beamDisplayIdx;
            obj.hModel.hBeams.beamsCalibrate(beamIdx);
        end
        
        function showCalibrationCurve(obj)
            beamIdx = obj.beamDisplayIdx;
            obj.hModel.hBeams.beamsShowCalibrationCurve(beamIdx);
        end
        
        function measureCalibrationOffset(obj)
            beamIdx = obj.beamDisplayIdx;
            offset = obj.hModel.hBeams.beamsMeasureCalOffset(beamIdx,true);
            if ~isnan(offset)
                msg = sprintf('Calibration offset voltage: %.3g. Result saved to Machine Data file.',offset);
                msgbox(msg,'Calibration offset measured');
            end
        end
        
        %% IMAGE FUNCTION CALLBACKS
        function showChannelDisplay(obj,channelIdx)
            set(obj.hModel.hFigs(channelIdx),'visible','on');
        end
        
        function showMergeDisplay(obj,channelIdx)
            if ~obj.hModel.channelsMergeEnable
                obj.hModel.channelsMergeEnable = true;
            end
        end
        
        function imageFunction(obj,fcnName)
            hFig = obj.zzzSelectImageFigure();
            if isempty(hFig)
                return;
            end
            
            allChannelFigs = [ obj.hModel.hFigs obj.hModel.hMergeFigs ];
            [tf chanIdx] = ismember(hFig,allChannelFigs);
            if tf
                feval(fcnName,obj.hModel,chanIdx);
            end
            
        end
        
        %% MOTOR CALLBACKS
        function motorZeroAction(obj,action)
            feval(action,obj.hModel.hMotors);
            obj.changedMotorPosition();
        end
        
        function motorDefineUserPositionAndIncrement(obj)
            usrPosnIdx = obj.motorUserPositionIndex;
            if usrPosnIdx > 0
                obj.hModel.hMotors.motorDefineUserPosition(usrPosnIdx);
                obj.motorUserPositionIndex = usrPosnIdx + 1;
            end
        end
        
        function motorGotoUserPosition(obj)
            usrPosnIdx = obj.motorUserPositionIndex;
            if usrPosnIdx > 0
                obj.hModel.hMotors.motorGotoUserDefinedPosition(usrPosnIdx);
            end
        end
        
        function motorLoadUserPositions(obj,handles)
            obj.hModel.hMotors.motorLoadUserDefinedPositions();
            obj.motorUserPositionIndex = 1;
        end
        
        function motorStepPosition(obj,incOrDec,stepDim)
            posn = obj.hModel.motorPosition;
            switch incOrDec
                case 'inc'
                    stepSign = 1;
                case 'dec'
                    stepSign = -1;
                otherwise
                    assert(false);
            end
            
            switch stepDim
                case 'x'
                    posn(1) = posn(1) + (stepSign * obj.motorStepSize(1));
                case 'y'
                    posn(2) = posn(2) + (stepSign * obj.motorStepSize(2));
                case 'z'
                    
                    if obj.hModel.hMotors.motorSecondMotorZEnable
                        if strcmpi(obj.hModel.hMotors.motorDimensionConfiguration,'xyz-z')
                            posnIdx = 4;
                        else
                            posnIdx = 3;
                        end
                        
                        %Make 'decrement' = 'down'/'deeper'
                        if obj.hModel.hMotors.mdfData.motor2ZDepthPositive
                            stepSign = stepSign * -1;
                        end
                    else
                        posnIdx = 3;
                        
                        %Make 'decrement' = 'down'/'deeper'
                        if obj.hModel.hMotors.mdfData.motorZDepthPositive
                            stepSign = stepSign * -1;
                        end
                    end
                    
                    posn(posnIdx) = posn(posnIdx) + (stepSign * obj.motorStepSize(3));
                    
                otherwise
                    assert(false);
            end
            
            obj.hModel.motorPosition = posn;
            
        end
        
        %% MOTOR ERROR CALLBACKS
        function motorErrorCbk(obj,src,evt) %#ok<INUSD>
            structfun(@nstDisable,obj.hGUIData.motorControlsV4);
            
            set(obj.hGUIData.motorControlsV4.pbRecover,'Visible','on');
            set(obj.hGUIData.motorControlsV4.pbRecover,'Enable','on');
            uistack(obj.hGUIData.motorControlsV4.pbRecover,'top');
            
            function nstDisable(h)
                if isprop(h,'Enable')
                    set(h,'Enable','off');
                end
            end
        end
        
        function motorRecover(obj)
            if obj.hModel.hMotors.motorHasMotor && obj.hModel.hMotors.hMotor.lscErrPending
                obj.hModel.hMotors.hMotor.recover();
            end
            if obj.hModel.hMotors.motorHasSecondMotor && obj.hModel.hMotors.hMotorZ.lscErrPending
                obj.hModel.hMotors.hMotorZ.recover();
            end
            
            % if we made it this far, then assume the error is fixed
            structfun(@nstEnable,obj.hGUIData.motorControlsV4);
            
            set(obj.hGUIData.motorControlsV4.pbRecover,'Visible','off');
            set(obj.hGUIData.motorControlsV4.pbRecover,'Enable','off');
            
            function nstEnable(h)
                if isprop(h,'Enable')
                    set(h,'Enable','on');
                end
            end
        end
        
        function stackSetStackStart(obj)
            obj.hModel.stackSetStackStart();
            % xxx DOC why it would be a bad idea for hModel to have a
            % dependent, setAccess=private, setobservable prop called
            % "tfStackStartEndPowersDefined" and for appC to listen to that
            % prop.
            if obj.hModel.hBeams.stackStartEndPowersDefined
                set(obj.hGUIData.motorControlsV4.cbOverrideLz,'Enable','on');
            end
        end
        
        function stackSetStackEnd(obj)
            obj.hModel.stackSetStackEnd();
            if obj.hModel.hBeams.stackStartEndPowersDefined
                set(obj.hGUIData.motorControlsV4.cbOverrideLz,'Enable','on');
            end
        end
        
        function stackClearStartEnd(obj)
            obj.hModel.stackClearStartEnd();
            set(obj.hGUIData.motorControlsV4.cbOverrideLz,'Enable','off');
        end
        
        function stackClearEnd(obj)
            obj.hModel.stackClearEnd();
            set(obj.hGUIData.motorControlsV4.cbOverrideLz,'Enable','off');
        end
        
        function toggleLineScan(obj,src,evnt)
            
            lineScanEnable = get(src,'Value');
            
            if lineScanEnable
                obj.hModel.scanParamSetBase();
                obj.hModel.scanAngleMultiplierSlow = 0;
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','inactive');
            else
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','on');
                obj.hModel.scanParamResetToBase({'scanAngleMultiplierSlow'});
                if obj.hModel.scanAngleMultiplierSlow == 0 %No CFG file, or CFG file has no scanAngleMultiplierSlow value, or Base value=0
                    obj.hModel.scanAngleMultiplierSlow = 1;
                end
            end
            
        end
        
        %% PMTS Callbacks
        function changePmtsPowersOn(obj,pmtNum,val)
            if nargin < 3 || isempty(val)
                val = false;
            end
            
            numPmts = obj.hModel.hPMTs.numInstances;
            if isempty(pmtNum)
                obj.hModel.hPMTs.powersOn = repmat(val,1,numPmts);
            else
                obj.hModel.hPMTs.hPmtControllers{1}.setPmtPower(pmtNum, ~obj.hModel.hPMTs.powersOn(pmtNum));
                %obj.hModel.hPMTs.powersOn(pmtNum) = ~obj.hModel.hPMTs.powersOn(pmtNum);
            end
            
            obj.hModel.hPMTs.updateStatus();
        end
        
        function changedPmtsPowersOn(obj,src,evnt)
            powersOn = logical(obj.hModel.bscope2PmtPowersOn);
            for i = 1:numel(obj.hModel.hPMTs.powersOn)
                pbTag = sprintf('pbPmt%dPower',i);
                
                if powersOn(i)
                    pbString = 'On';
                else
                    pbString = 'Off';
                end
                set(obj.hGUIData.pmtControlsV5.(pbTag),'String',pbString);
                set(obj.hGUIData.pmtControlsV5.(pbTag),'Value',double(~powersOn(i))); % toggle button value to clear focus
                set(obj.hGUIData.pmtControlsV5.(pbTag),'Value',powersOn(i));
            end
            drawnow
        end
        
        function changePmtsGains(obj,pmtNum,val)
           obj.hModel.hPMTs.hPmtControllers{1}.setPmtGain(pmtNum, val);
           obj.hModel.hPMTs.updateStatus();
        end
        
        function changedPmtsGains(obj,src,evnt)
            gains = double(obj.hModel.hPMTs.gains);
            for i = 1:numel(obj.hModel.hPMTs.gains)
                etTag = sprintf('etPmt%dGain',i);
                set(obj.hGUIData.pmtControlsV5.(etTag),'String',gains(i));
            end
        end
        
        function pmtsResetTripped(obj,pmtNum)
            if obj.hModel.hPMTs.powersOn(pmtNum)
                obj.hModel.hPMTs.powersOn(pmtNum) = false;
                obj.hModel.hPMTs.powersOn(pmtNum) = true;
            end
        end
        
        function changedPmtsTripped(obj,src,evnt)
            pmtsTripped = double(obj.hModel.hPMTs.tripped);
            for i = 1:numel(obj.hModel.hPMTs.powersOn)
                etTag = sprintf('etPmt%dStatus',i);
                if pmtsTripped(i)
                    etString = 'Tripped';
                    bgColor = 'r';
                else
                    etString = 'OK';
                    bgColor = [1 1 1];
                end
                set(obj.hGUIData.pmtControlsV5.(etTag),'String',etString);
                set(obj.hGUIData.pmtControlsV5.(etTag),'BackgroundColor',bgColor);
            end
        end
        
        %% BScope2 Callbacks
        function changedFlipperMirrorPosition(obj,src,evnt)
            if ~isempty(obj.hModel.hBScope2)
                if obj.hModel.hBScope2.lscInitSuccessful
                    switch obj.hModel.bscope2FlipperMirrorPosition
                        case 'pmt'
                            set(obj.hGUIData.bScope2ControlsV5.pbCamera,'Value',true);
                            set(obj.hGUIData.bScope2ControlsV5.pbCamera,'Value',false); %must toggle to clear focus for new
                            set(obj.hGUIData.bScope2ControlsV5.pbPmt,'Value',false);    %value to stick
                            set(obj.hGUIData.bScope2ControlsV5.pbPmt,'Value',true);

                        case 'camera'
                            set(obj.hGUIData.bScope2ControlsV5.pbPmt,'Value',true);
                            set(obj.hGUIData.bScope2ControlsV5.pbPmt,'Value',false);     %must toggle to clear focus for new
                            set(obj.hGUIData.bScope2ControlsV5.pbCamera,'Value',false);  %value to stick
                            set(obj.hGUIData.bScope2ControlsV5.pbCamera,'Value',true);
                    end
                end
            end
        end
        
        
        function changeFlipperMirrorPosition(obj, val)
            obj.hModel.bscope2FlipperMirrorPosition = val;
        end
        
        
        function changedGalvoResonantMirrorInPath(obj,src,evnt)
            if ~isempty(obj.hModel.hBScope2)
                if obj.hModel.hBScope2.lscInitSuccessful
                    if obj.hModel.bscope2GalvoResonantMirrorInPath
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_Out,'Value',true);
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_Out,'Value',false);   %must toggle to clear focus for new
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_In,'Value',false);    %value to stick
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_In,'Value',true);
                    else
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_In,'Value',true);
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_In,'Value',false);     %must toggle to clear focus for new
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_Out,'Value',false);    %value to stick
                        set(obj.hGUIData.bScope2ControlsV5.pbGR_Out,'Value',true);
                    end
                end
            end
        end
        
        
        function changeGalvoResonantMirrorInPath(obj, val)
            obj.hModel.bscope2GalvoResonantMirrorInPath = val;
        end
        
        
        function changedGalvoGalvoMirrorInPath(obj,src,evnt)
            if ~isempty(obj.hModel.hBScope2)
                if obj.hModel.hBScope2.lscInitSuccessful
                    if obj.hModel.bscope2GalvoGalvoMirrorInPath
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_Out,'Value',true);
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_Out,'Value',false);   %must toggle to clear focus for new
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_In,'Value',false);    %value to stick
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_In,'Value',true);
                    else
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_In,'Value',true);
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_In,'Value',false);     %must toggle to clear focus for new
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_Out,'Value',false);    %value to stick
                        set(obj.hGUIData.bScope2ControlsV5.pbGG_Out,'Value',true);
                    end
                end
            end
        end
        
        
        function changeGalvoGalvoMirrorInPath(obj, val)
            obj.hModel.bscope2GalvoGalvoMirrorInPath = val;
        end
        
        
        function setBScope2RotationAngle(obj, val)
            if ~isempty(obj.hModel.hBScope2)
                if obj.hModel.hBScope2.lscInitSuccessful
                    if numel(val) == 1 && ~isnan(val)
                        validateattributes(val,{'numeric'},{'scalar', '>=',-180,'<=',180});
                        obj.hModel.hBScope2.completeRotation(val);
                        obj.changedBScope2RotationAngle();
                    end
                end
            end
        end
        
        function stepBScope2RotationAngle(obj, mult)
            if ~isempty(obj.hModel.hBScope2)
                if obj.hModel.hBScope2.lscInitSuccessful
                    val = obj.hModel.hBScope2.rotationAngleAbsolute + obj.bScope2RotationAngleStepSize * mult;
                    validateattributes(val,{'numeric'},{'scalar', '>=',-180,'<=',180});
                    obj.hModel.hBScope2.completeRotation(val);
                    obj.changedBScope2RotationAngle();
                end
            end
        end
        
        function changedBScope2RotationAngle(obj,~,~)
            formatStr = '%.1f';
            
            rotationAngle = obj.hModel.bScope2RotationAngle;
            if ~isempty(rotationAngle)
                set(obj.hGUIData.bScope2ControlsV5.etRotationAngle,'String',num2str(rotationAngle,formatStr));
            end
        end
        
    end
    
    %% CONTROLLER PROPERTY CALLBACKS
    
    methods (Hidden)
        
        function changeChannelsTargetDisplay(obj,src)
            val = get(src,'Value');
            switch val
                case 1 %None selected
                    obj.channelsTargetDisplay = [];
                case obj.hModel.MAX_NUM_CHANNELS + 2
                    obj.channelsTargetDisplay = inf;
                otherwise
                    obj.channelsTargetDisplay = val - 1;
            end
        end
        
    end
    
    
    %% PRIVATE/PROTECTED METHODS
    
    methods (Access=protected)
        
        function hFig = zzzSelectImageFigure(obj)
            %Selects image figure, either from channelsTargetDisplay property or by user-selection
            
            hFig = [];
            
            if isempty(obj.channelsTargetDisplay)
                obj.mainControlsStatusString = 'Select image...';
                chanFigs = [ obj.hModel.hFigs obj.hModel.hMergeFigs ] ;
                hFig = most.gui.selectFigure(chanFigs);
                obj.mainControlsStatusString = '';
            elseif isinf(obj.channelsTargetDisplay)
                hFig = obj.hModel.hMergeFigs;
            else
                hFig = obj.hModel.hFigs(obj.channelsTargetDisplay);
            end
        end
        
    end
    
    
    %% USER FUNCTION RELATED METHODS
    methods
        function viewType = get.userFunctionsViewType(obj)
            viewBtn = get(obj.hGUIData.userFunctionControlsV4.bgView,'SelectedObject');
            if ~isempty(viewBtn)
                switch get(viewBtn,'Tag')
                    case 'tbUsr'
                        viewType = 'USR';
                    case 'tbCfg'
                        viewType = 'CFG';
                end
            else
                viewType = 'none';
            end
        end
        
        function evtNames = get.userFunctionsCurrentEvents(obj)
            switch obj.userFunctionsViewType
                case 'none'
                    evtNames = cell(0,1);
                case 'CFG'
                    evtNames = obj.hModel.USER_FUNCTIONS_EVENTS;
                case 'USR'
                    evtNames = sort([obj.hModel.USER_FUNCTIONS_EVENTS;obj.hModel.USER_FUNCTIONS_USR_ONLY_EVENTS]);
            end
        end
        
        function propName = get.userFunctionsCurrentProp(obj)
            switch obj.userFunctionsViewType
                case 'none'
                    propName = '';
                case 'CFG'
                    propName = 'userFunctionsCfg';
                case 'USR'
                    propName = 'userFunctionsUsr';
            end
        end
        
        function changedUserFunctionsCfg(obj,~,~)
            switch obj.userFunctionsViewType
                case 'CFG'
                    obj.hGUIData.userFunctionControlsV4.uft.refresh();
            end
        end
        
        function changedUserFunctionsUsr(obj,~,~)
            switch obj.userFunctionsViewType
                case 'USR'
                    obj.hGUIData.userFunctionControlsV4.uft.refresh();
            end
        end
        
        function changedUserFunctionsOverride(obj,~,~)
            obj.hGUIData.userFunctionControlsV4.uftOverride.refresh();
        end
        
        function changedLoggingFramesPerFileLock(obj,~,~)
            if obj.hModel.loggingFramesPerFileLock
                set(obj.hGUIData.configControlsV4.etFramesPerFile,'Enable','off');
            else
                set(obj.hGUIData.configControlsV4.etFramesPerFile,'Enable','on');
            end
        end
    end
    
    % end user function related methods
    
end

%% LOCAL FUNCTIONS


function v = zlclShortenFilename(v)
assert(ischar(v));
[~,v] = fileparts(v);
end

%helper for changedStackStartEndPositionPower
function zlclEnableUIControlBasedOnVal(hUIC,val,enableOn)
if isnan(val)
    set(hUIC,'Enable','off');
else
    set(hUIC,'Enable',enableOn);
end

end


function propBindings = lclInitPropBindings()

%NOTE: In this prop metadata list, order does NOT matter!
%NOTE: These are properties for which some/all handling of model-view linkage is managed 'automatically' by this class

%TODO: Some native approach for dependent properties could be specified here, to handle straightforward cases where change in one property affects view of another -- these are now handled as 'custom' behavior with 'Callbacks'
%      For example: scanLinePeriodUS value depends on scanMode


s = struct();

%% Display props
s.acqNumAveragedFrames = struct('GuiIDs',{{'mainControlsV4','etNumAvgFramesSave'}});

s.displayShowCrosshair = struct('GuiIDs',{{'imageControlsV4','mnu_Settings_ShowCrosshair'}});
s.displayRollingAverageFactor = struct('GuiIDs',{{'imageControlsV4','etRollingAverage'}});
s.displayRollingAverageFactorLock = struct('GuiIDs',{{'imageControlsV4','cbLockRollAvg2AcqAvg'}},'Callback','changedDisplayRollingAverageFactorLock');
s.displayFrameBatchFactor = struct('GuiIDs',{{'imageControlsV4','etFrameSelFactor'}});
s.displayFrameBatchSelection = struct('GuiIDs',{{'imageControlsV4','etFrameSelections'}});
s.displayFrameBatchSelectLast = struct('GuiIDs',{{'imageControlsV4','cbUseLastSelFrame'}},'Callback','changedDisplayFrameBatchSelectLast');
s.displayFrameBatchFactorLock = struct('GuiIDs',{{'imageControlsV4','cbLockFrameSel2RollAvg'}},'Callback','changedDisplayFrameBatchFactorLock');

%s.scanAngleMultiplierFast = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierFast'}});
s.scanAngleMultiplierSlow = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierSlow'}},'Callback','changedScanAngleMultiplierSlow');
s.scanShiftSlow = struct('GuiIDs',{{'mainControlsV4','scanShiftSlow'}});

%% Channel Props
s.chan1LUT = struct('Callback','changedChanLUT');
s.chan2LUT = struct('Callback','changedChanLUT');
s.chan3LUT = struct('Callback','changedChanLUT');
s.chan4LUT = struct('Callback','changedChanLUT');

s.zoomFactor = struct('GuiIDs',{{'mainControlsV4' 'pcZoom'}});
s.pixelsPerLine = struct('GuiIDs',{{'configControlsV4','pmPixelsPerLine'}});
s.linesPerFrame = struct('GuiIDs',{{'configControlsV4','etLinesPerFrame'}});
s.linePeriod_ = struct('GuiIDs',{{'configControlsV4','etLinePeriod'}},'ViewScaling',1e6,'ViewPrecision',5);
s.fillFractionTime = struct('GuiIDs',{{'configControlsV4','etFillFrac'}});
s.fillFraction = struct('GuiIDs',{{'configControlsV4','etFillFracSpatial'}},'ViewPrecision','%0.3f');
s.scanPixelTimeMean = struct('GuiIDs',{{'configControlsV4','etPixelTimeMean'}},'ViewScaling',1e9,'ViewPrecision','%.1f');
s.scanPixelTimeMaxMinRatio = struct('GuiIDs',{{'configControlsV4','etPixelTimeMaxMinRatio'}},'ViewPrecision','%.1f');
s.scanForceSquarePixelation = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixelation'}});
s.scanForceSquarePixel  = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixel'}});
s.scanForceSquarePixelation_ = struct('Callback','changedScanForceSquarePixelation_');
s.scanForceSquarePixel_ = struct('Callback','changedForceSquarePixels');

s.bidirectionalAcq = struct('GuiIDs',{{'configControlsV4','cbBidirectionalScan'}});
s.scanFrameRate_ = struct('GuiIDs',{{'configControlsV4','etFrameRate'}},'ViewPrecision','%.2f');
s.scanFramePeriod = struct('GuiIDs',{{'fastZControlsV4','etFramePeriod'}},'ViewPrecision','%.1f','ViewScaling',1000,'Callback','changedScanFramePeriod');

s.loggingEnable = struct('GuiIDs',{{'mainControlsV4','cbAutoSave','configControlsV4','cbAutoSave'}},'Callback','changedLoggingEnable');
s.loggingFileStem = struct('GuiIDs',{{'mainControlsV4' 'baseName'}});
s.loggingFileCounter = struct('GuiIDs',{{'mainControlsV4' 'fileCounter'}});
s.loggingFramesPerFile = struct('GuiIDs',{{'configControlsV4' 'etFramesPerFile'}});
s.loggingFramesPerFileLock = struct('GuiIDs',{{'configControlsV4' 'cbFramesPerFileLock'}},'Callback','changedLoggingFramesPerFileLock');

% acquisition State
s.frameCounterDisplay = struct('GuiIDs',{{'mainControlsV4','framesDone'}});
s.loopAcqCounter = struct('GuiIDs',{{'mainControlsV4','repeatsDone'}});
s.acqNumFrames = struct('GuiIDs',{{'mainControlsV4','framesTotal'}});
s.acqsPerLoop = struct('GuiIDs',{{'mainControlsV4','repeatsTotal'}});

s.acqState = struct('Callback','changedAcqState','GuiIDs',{{'mainControlsV4' 'statusString'}});
s.triggerTypeExternal = struct('GuiIDs',{{'mainControlsV4' 'tbExternalTrig'}});
%s.triggerExternalAvailable = struct('Callback','changedTriggerExternalAvailable');
%s.triggerExternalTypes = struct('Callback','changedTriggerDialogData','PropControlData',struct('columnIdx',2,'format','logicalindices','formatInfo',[]));
s.triggerExternalTypes = struct('PropControlData',struct('columnIdx',1,'format','logicalindices','formatInfo',[]));
s.triggerExternalTerminals = struct('Callback','changedTriggerDialogData','PropControlData',struct('columnIdx',2,'format','logicalindices','formatInfo',[]));
s.triggerExternalEdges = struct('Callback','changedTriggerDialogData','PropControlData',struct('columnIdx',3,'format','logicalindices','formatInfo',[]));
s.periodClockPhase = struct('GuiIDs',{{'configControlsV4','etScanPhase'}},'Callback','changedScanPhase');

%channels
s.channelsDisplay = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',2,'format','logicalindices','formatInfo',[]));
s.channelsSave = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',1,'format','logicalindices','formatInfo',[]));
s.channelsInputRange = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',3,'format','options'));
s.channelOffsets = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',4,'format','numeric'));
s.channelsSubtractOffset = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',5,'format','logical'));
s.channelsAutoReadOffsets = struct('GuiIDs',{{'channelControlsV4','cbAutoReadOffsets'}});

s.channelsMergeColor = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',6,'format','options','prettyOptions',{{'Green' 'Red' 'Blue' 'Gray' 'None'}}));
s.channelsMergeEnable = struct('GuiIDs',{{'channelControlsV4','cbMergeEnable'}},'Callback','changedChannelsMergeEnable');
s.channelsMergeFocusOnly = struct('GuiIDs',{{'channelControlsV4','cbChannelsMergeFocusOnly'}});

s.loopAcqInterval = struct('GuiIDs',{{'mainControlsV4','etRepeatPeriod'}});
s.secondsCounter = struct('Callback','changedSecondsCounter');
s.frameAcqFcnDecimationFactor = struct('GuiIDs',{{'configControlsV4' 'etFrameAcqFcnDecimationFactor'}});

%% STACK STRUCTS
s.stackSlicesDone = struct('GuiIDs',{{'mainControlsV4','slicesDone'}});
s.stackNumSlices = struct('GuiIDs',{{'mainControlsV4','slicesTotal','motorControlsV4','etNumberOfZSlices','fastZControlsV4','etNumZSlices'}});
s.stackZStartPos = struct('GuiIDs',{{'motorControlsV4','etStackStart'}},'Callback','changedStackStartEndPositionPower');
s.stackZEndPos = struct('GuiIDs',{{'motorControlsV4','etStackEnd'}},'Callback','changedStackStartEndPositionPower');
s.stackStartPower = struct('GuiIDs',{{'motorControlsV4','etStartPower'}},'Callback','changedStackStartEndPositionPower');
s.stackEndPower = struct('GuiIDs',{{'motorControlsV4','etEndPower'}},'Callback','changedStackStartEndPositionPower');
s.stackUseStartPower = struct('GuiIDs',{{'motorControlsV4','cbUseStartPower'}},'Callback','changedStackUseStartPower');
s.stackUserOverrideLz = struct('GuiIDs',{{'motorControlsV4','cbOverrideLz'}},'Callback','changedOverrideLz');
s.stackZStepSize = struct('GuiIDs',{{'motorControlsV4','etZStepPerSlice','fastZControlsV4','etZStepPerSlice'}});
s.stackReturnHome = struct('GuiIDs',{{'motorControlsV4','cbReturnHome','fastZControlsV4','cbReturnHome'}});
s.stackStartCentered = struct('GuiIDs',{{'motorControlsV4','cbCenteredStack','fastZControlsV4','cbCenteredStack'}});

%% MOTOR STRUCTS
s.motorPosition = struct('Callback','changedMotorPosition');
s.motorSecondMotorZEnable = struct('GuiIDs',{{'motorControlsV4','cbSecZ'}});

%% FASTZ STRUCTS
s.fastZEnable = struct('GuiIDs',{{'fastZControlsV4','cbEnable'}},'Callback','changedFastZEnable');
s.fastZNumVolumes = struct('GuiIDs',{{'fastZControlsV4','etNumVolumes'}});
s.fastZImageType = struct('GuiIDs',{{'fastZControlsV4','pmImageType'}});
s.fastZScanType = struct('GuiIDs',{{'fastZControlsV4','pmScanType'}},'Callback','changedFastZScanType','PrettyOptions',{{'Step' 'Sawtooth'}});
%s.fastZSettlingTime = struct('GuiIDs',{{'fastZControlsV4','etSettlingTime'}});
s.fastZSettlingTime = struct('Callback','changedFastZSettlingTime');
s.fastZDiscardFlybackFrames = struct('GuiIDs',{{'fastZControlsV4','cbDiscardFlybackFrames'}},'Callback','changedFastZDiscardFlybackFrames');
s.fastZFramePeriodAdjustment = struct('GuiIDs',{{'fastZControlsV4','pcFramePeriodAdjust'}});
s.fastZVolumesDone = struct('GuiIDs',{{'fastZControlsV4','etVolumesDone'}});
s.fastZNumDiscardFrames = struct('GuiIDs',{{'fastZControlsV4','etNumDiscardFrames'}});

%% BEAM STRUCTS
s.beamFlybackBlanking = struct('GuiIDs',{{'configControlsV4','cbBlankFlyback'}});
s.acqBeamOverScan = struct('GuiIDs',{{'configControlsV4','etBeamLead'}});
s.beamPowersDisplay = struct('Callback','changedBeamParams');
s.beamPowerLimits = struct('Callback','changedBeamParams');
s.beamLiveAdjust = struct('GuiIDs',{{'powerControlsV4','cbLiveAdjust'}});
s.beamDirectMode = struct('GuiIDs',{{'powerControlsV4','cbDirectMode'}});
s.beamPowerUnits = struct('Callback','changedBeamPowerUnits');
s.beamPzAdjust = struct('Callback','changedBeamPzAdjust');
s.beamLengthConstants = struct('Callback','changedBeamParams');

%% USR/CFG/FASTCFG
s.cfgFilename = struct('Callback','changedCfgFilename');
s.usrFilename = struct('Callback','changedUsrFilename');
s.usrPropListCurrent = struct('Callback','changedUsrPropListCurrent');

s.fastCfgCfgFilenames = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',...
    struct('columnIdx',3,'format','cellstr','customEncodeFcn',@zlclShortenFilename),'Callback','changedFastCfgCfgFilenames');
s.fastCfgAutoStartTf = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',...
    struct('columnIdx',4,'format','logical'),'Callback','changedFastCfgAutoStartTf');
s.fastCfgAutoStartType = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',...
    struct('columnIdx',5,'format','options'));

%% USER FUNCTIONS
s.userFunctionsCfg = struct('Callback','changedUserFunctionsCfg');
s.userFunctionsUsr = struct('Callback','changedUserFunctionsUsr');
s.userFunctionsOverride = struct('Callback','changedUserFunctionsOverride');

%% PMTS
s.bscope2PmtPowersOn = struct('Callback','changedPmtsPowersOn');
s.bscope2PmtGains    = struct('Callback','changedPmtsGains');
s.bscope2PmtTripped  = struct('Callback','changedPmtsTripped');

%% BScope2
s.bscope2FlipperMirrorPosition = struct('Callback','changedFlipperMirrorPosition');
s.bscope2GalvoResonantMirrorInPath = struct('Callback','changedGalvoResonantMirrorInPath');
s.bscope2GalvoGalvoMirrorInPath = struct('Callback','changedGalvoGalvoMirrorInPath');
s.bScope2RotationAngle = struct('Callback','changedBScope2RotationAngle');
s.bscope2ScanAlign = struct('GuiIDs',{{'bScope2ControlsV5','etScanAlign','bScope2ControlsV5','slScanAlign'}});

%% output
propBindings = s;

end

%--------------------------------------------------------------------------%
% SI5Controller.m                                                          %
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
