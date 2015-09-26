function varargout = triggerControlsV5(varargin)
% TRIGGERCONTROLSV5 MATLAB code for triggerControlsV5.fig
%      TRIGGERCONTROLSV5, by itself, creates a new TRIGGERCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = TRIGGERCONTROLSV5 returns the handle to a new TRIGGERCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      TRIGGERCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TRIGGERCONTROLSV5.M with the given input arguments.
%
%      TRIGGERCONTROLSV5('Property','Value',...) creates a new TRIGGERCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before triggerControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to triggerControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help triggerControlsV5

% Last Modified by GUIDE v2.5 01-Jul-2014 16:59:06

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @triggerControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @triggerControlsV5_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before triggerControlsV5 is made visible.
function triggerControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to triggerControlsV5 (see VARARGIN)

% Choose default command line output for triggerControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes triggerControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = triggerControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes when entered data in editable cell(s) in tblTriggerConfig.
function tblTriggerConfig_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tblTriggerConfig (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changeTriggerDialogData(hObject, eventdata);


% --- Executes on button press in pbAcqStart.
function pbAcqStart_Callback(hObject, eventdata, handles)
% hObject    handle to pbAcqStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.generateAcqStartTrigger();


% --- Executes on button press in pbAcqStop.
function pbAcqStop_Callback(hObject, eventdata, handles)
% hObject    handle to pbAcqStop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.generateAcqStopTrigger();

% --- Executes on button press in pbNextFileMarker.
function pbNextFileMarker_Callback(hObject, eventdata, handles)
% hObject    handle to pbNextFileMarker (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.generateNextFileMarkerTrigger();



%--------------------------------------------------------------------------%
% triggerControlsV5.m                                                      %
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
