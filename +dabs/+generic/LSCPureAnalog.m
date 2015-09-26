classdef LSCPureAnalog < dabs.interfaces.LSCAnalogOption & most.MachineDataFile
    %LSCPureAnalog Summary of this class goes here
    %   Detailed explanation goes here

    %% PROPERTIES (Constructor-initialized)
    properties (SetAccess=immutable)
        
        commandVoltsPerMicron; %Conversion factor for command signal to analog linear stage controller
        commandVoltsOffset; %Offset value, in volts, for command signal to analog linear stage controller
        
        sensorVoltsPerMicron; %Conversion signal for sensor signal from analog linear stage controller
        sensorVoltsOffset; %Offset value, in volts, for sensor signal from analog linear stage controller
                
    end
    
    %% HIDDEN PROPS
    properties (Hidden, SetAccess=private)
       analogOptionInitialized = false;        
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'LSC Pure Analog';
        
        %Value-Optional properties
        mdfDependsOnClasses;
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
    end
    
    %% ABSTRACT PROPERTY REALIZATION (dabs.interfaces.LSCAnalogOption)
    properties (SetAccess=protected,Hidden)
        analogCmdEnableRaw = false
    end
        
        
    %% ABSTRACT PROPERTY REALIZATION (dabs.interface.LinearStageController)
    
    properties (Constant, Hidden)
        nonblockingMoveCompletedDetectionStrategy = 'poll'; % Either 'callback' or 'poll'. If 'callback', this class guarantees that moveDone() will be called when a nonblocking move is complete. See documentation for moveStartHook().
    end
    
    properties (SetAccess=protected,Dependent)
        infoHardware;
    end
    
    properties (SetAccess=protected,Dependent,Hidden)
        velocityRaw;
        accelerationRaw;

        invertCoordinatesRaw;
        maxVelocityRaw;

    end
    
    properties (SetAccess=protected, Hidden)
        resolutionRaw;
        
        positionDeviceUnits = 1e-6;
        velocityDeviceUnits = 1e-6;
        accelerationDeviceUnits = 1e-6;
    end   
    
    
    
    %% OBJECT LIFECYCLE
    methods
        function obj = LSCPureAnalog(varargin)
            
            %REMOVE
            % obj = LSCPureAnalog(p1,v1,p2,v2,...)
            %
            % P-V options:
            % hAOBuffered: (OPTIONAL)  Handle to NI.DAQmx AO Task object used by client which also controls same analogCmdBoard/ChannelID for buffered AO operations 
            %
                        
            
            %Construct dabs.interfaces.analogLSC
            obj = obj@dabs.interfaces.LSCAnalogOption(varargin{:});
            
            %Initiallize dabs.interfaces.analogLSC
            pvCell = most.util.filterPVArgs(varargin,{'hAOBuffered'},{});
            pvStruct = most.util.cellPV2structPV(pvCell);            
            
            argList = { ...
                'analogCmdBoardID', obj.mdfData.analogCmdBoardID, ...
                'analogCmdChanIDs', obj.mdfData.analogCmdChanIDs, ...
                'analogSensorBoardID', obj.mdfData.analogSensorBoardID, ...
                'analogSensorChanIDs', obj.mdfData.analogSensorChanIDs};                   
            
            if isfield(pvStruct,'hAOBuffered')
                argList = [argList {'hAOBuffered' pvStruct.hAOBuffered}];
            end
            
            
            %Initialize analog option for parent LSCAnalogOption class
            obj.initializeAnalogOption(argList{:});  
            obj.analogOptionInitialized = true;
            
            %Initialize transform (scale/offset) properties
            xformProps = {'commandVoltsPerMicron' 'sensorVoltsPerMicron' 'commandVoltsOffset' 'sensorVoltsOffset'}; 
                  
            for i=1:length(xformProps)
                obj.(xformProps{i}) = obj.mdfData.(xformProps{i});
            end            
            
            %Turn on analog 'option' (which must be/remain True, for this 'pure' analog class)
            obj.analogCmdEnable = true; 

            
            
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        
        function set.analogCmdEnableRaw(obj,val)
            
            %Coerce True value for analogCmdEnable
            if val ~= true                
                if obj.analogOptionInitialized %Don't warn during initializeAnalogOption() call
                    warning('Cannot set analogCmdEnable to value False for objects of class ''%s''',mfilename('class'));
                end
                obj.analogCmdEnableRaw = true;
            end
        end            
        
        function val = get.infoHardware(~)
            val = 'Analog Only FastZ Actuator Device';                                    
        end
        
        function val = get.invertCoordinatesRaw(obj)
            val = false(1,obj.numDeviceDimensions);
        end        
                
        function val = get.velocityRaw(~)
            val = nan;
        end
        
        function val = get.accelerationRaw(~)
            val = nan;
        end
        
        function val = get.maxVelocityRaw(~)
            val = nan;
        end  
   
    end
    
    %% ABSTRACT METHOD IMPLEMENTATION  (dabs.interfaces.LSCAnalogOption)
    
    methods
        
        function voltage = analogCmdPosn2Voltage(obj,posn)
            %Convert LSC position values into analog voltage (scalar function, applies to all dimensions)
            voltage = obj.commandVoltsPerMicron * posn + obj.commandVoltsOffset;
        end
        
        function posn = analogSensorVoltage2Posn(obj,voltage)
            %Convert analog voltage into LSC position values (scalar function, applies to all dimensions)
            posn = (voltage + obj.sensorVoltsOffset)  / obj.sensorVoltsPerMicron;
        end       
        
    end
    
    methods (Access=protected)
        
        
        function posn = positionAbsoluteRawDigitalHook(obj)
            %Provide default ('digital') readout of LSC's absolute position
            error('Objects of class ''%s'' do not support digital position readout',mfilename('class'));
        end
        
        function tf = isMovingDigitalHook(obj)
            %Provide default ('digital') determination of whether LSC is moving when analogCndEnable=false
            error('Objects of class ''%s'' do not support digital readout of isMoving status',mfilename('class'));
        end
        function moveStartDigitalHook(obj,absTargetPosn)
            %Provide default ('digital') LSC move behavior when analogCmdEnable=false
            error('Objects of class ''%s'' do not support digital move operations',mfilename('class'));
        end                
        
    end
    
    methods (Access=protected,Hidden)
        function recoverHook(obj)
            %Do nothing
        end
    end
    
    %Method overrides
    methods (Access=protected)
         function tf = isMovingAnalogHook(obj)
             numReadings = 10; 
             
             initialPosition = mean(obj.hAILSC.readAnalogData(numReadings));
             pause(0.1);
             finalPosition = mean(obj.hAILSC.readAnalogData(numReadings));
             
             tf = abs(finalPosition-initialPosition) > obj.resolutionBest; 
            
         end                
    end
        
    

    
    

    
    
end



%--------------------------------------------------------------------------%
% LSCPureAnalog.m                                                          %
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
