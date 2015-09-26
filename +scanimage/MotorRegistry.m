classdef MotorRegistry
    
    methods (Static)
        
        function info = getControllerInfo(type)
            assert(ischar(type),'''type'' must be a stage controller type.');
            m = scanimage.MotorRegistry.controllerMap;
            if m.isKey(type)
                info = m(type);
            else
                info = [];
            end
            
            if isempty(info) && exist('scanimagev.MotorRegistry','class')
                m = scanimagev.MotorRegistry.controllerMap;
                
                if m.isKey(type)
                    info = m(type);
                end
            end
        end
        
    end
    
    properties (Constant,GetAccess=private)
        controllerMap = zlclInitControllerMap();
    end
    
    methods (Access=private)
        function obj = MotorRegistry()
        end
    end
    
end

function m = zlclInitControllerMap

m = containers.Map();

s = struct();
s.Names = {'mp285' 'sutter.mp285' 'sutter.MP285'};
s.Class = 'dabs.sutter.MP285';
s.SubType = '';
s.TwoStep.Enable = true;
s.TwoStep.FastLSCPropVals = struct('resolutionMode','coarse');
s.TwoStep.SlowLSCPropVals = struct('resolutionMode','fine');
s.TwoStep.InitSlowLSCProps = true;
s.SafeReset = true;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'mpc200' 'sutter.mpc200' 'sutter.MPC200'};
s.Class = 'dabs.sutter.MPC200';
s.SubType = '';
s.TwoStep.Enable = false;
%s.TwoStep.FastLSCPropVals = struct('resolutionMode','coarse');
%s.TwoStep.SlowLSCPropVals = struct('resolutionMode','fine');
s.SafeReset = false;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'pi.e816' 'pi.e665' 'pi.E816' 'pi.E665'};
s.Class = 'dabs.pi.LinearStageController';
s.SubType = 'e816';
s.TwoStep.Enable = false;
s.SafeReset = false;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'npoint.lc40x' 'npoint.LC40x'};
s.Class = 'dabs.npoint.LinearStageController';
s.SubType = 'LC40x';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'scientifica' 'scientifica.LinearStageController'};
s.Class = 'dabs.scientifica.LinearStageController';
s.SubType = '';
s.TwoStep.Enable = true;
s.TwoStep.FastLSCPropVals = struct(); %Velocity is switched between fast/slow, but determined programatically for each stage type
s.TwoStep.SlowLSCPropVals = struct(); %Velocity is switched between fast/slow, but determined programatically for each stage type
s.TwoStep.InitSlowLSCProps = false;
s.SafeReset = false;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'analog'};
s.Class = 'dabs.generic.LSCPureAnalog';
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = false;
zlclAddMotor(m,s);

s = struct();
s.Names = {'bscope2' 'thorlabs.bscope2' 'thorlabs.BScope2'};
s.Class = 'dabs.thorlabs.BScope2';
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'simulated.stage'};
s.Class = 'dabs.simulated.Stage';
s.SubType = '';
s.TwoStep.Enable = false; 
s.SafeReset = true;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'simulated.piezo'};
s.Class = 'dabs.simulated.Piezo';
s.SubType = '';
s.TwoStep.Enable = false; 
s.SafeReset = true;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

s = struct();
s.Names = {'dummy' 'dummies.DummyLSC'};
s.Class = 'dabs.dummies.DummyLSC';
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;
zlclAddMotor(m,s);

end

function zlclAddMotor(m,s)
names = s.Names;
for c = 1:length(names)
    m(names{c}) = s;
end
end


%--------------------------------------------------------------------------%
% MotorRegistry.m                                                          %
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
