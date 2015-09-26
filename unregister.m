function unregister

[p,~,~]=fileparts(mfilename('fullpath'));
ps=strsplit(genpath(p),pathsep);
m=cellfun(@(s) isempty(strfind(s,'.git')) && isempty(strfind(s,'.svn')),ps);

rmpath(strjoin(ps(m),pathsep));

%% sadly, pre-2013 matlab does not have strsplit and strjoin
% code copied off of the matlab file exchange and modified for brevity
function terms = strsplit(s, delimiter)
if nargin < 2
    by_space = true;
else
    d = delimiter;
    d = strtrim(d);
    by_space = isempty(d);
end
s = strtrim(s);

if by_space
    w = isspace(s);
    if any(w)
        % decide the positions of terms
        dw = diff(w);
        sp = [1, find(dw == -1) + 1];     % start positions of terms
        ep = [find(dw == 1), length(s)];  % end positions of terms
        
        % extract the terms
        nt = numel(sp);
        terms = cell(1, nt);
        for i = 1 : nt
            terms{i} = s(sp(i):ep(i));
        end
    else
        terms = {s};
    end
    
else
    p = strfind(s, d);
    if ~isempty(p)
        % extract the terms
        nt = numel(p) + 1;
        terms = cell(1, nt);
        sp = 1;
        dl = length(delimiter);
        for i = 1 : nt-1
            terms{i} = strtrim(s(sp:p(i)-1));
            sp = p(i) + dl;
        end
        terms{nt} = strtrim(s(sp:end));
    else
        terms = {s};
    end
end

%%
function s = strjoin(terms, delimiter)
% parse and verify input arguments
if nargin < 2
    d = ' ';
else
    d = delimiter;
end
% main
n = numel(terms);
if n == 0
    s = '';
elseif n == 1
    s = terms{1};
else
    ss = cell(1, 2*n-1);
    ss(1:2:end) = terms;
    [ss{2:2:end}] = deal(d);
    s = [ss{:}];
end


%--------------------------------------------------------------------------%
% unregister.m                                                             %
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
