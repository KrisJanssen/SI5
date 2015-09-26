%% Beams
beamModifiedLineClockIn = '';       % String: One of {PFI0..15, ''} to which external beam trigger is connected. Leave empty if DAQ device is in main PXI chassis

beamDeviceName = '';                % String: Device name containing beam modulation channels.
beamChanIDs = [];                   % Numeric: Array of integers specifying AO channel IDs, one for each beam modulation channel. Length of array determines number of 'beams'.
beamIDs = {};                       % {String}: Optional string cell array of identifiers for each beam
beamVoltageRanges = 1.5;            % Numeric [V]: Scalar or array of values specifying voltage range to use for each beam. Scalar applies to each beam.
shutterBeforeBeam = false;          % Logical: Indicates if shutter is before beam modulator. Single value, applying to all shutterLineIDs. (moved to beams class definition.

beamCalInputChanIDs = [];           % Numeric: Array of integers specifying AI channel IDs, one for each beam modulation channel. Values of nan specify no calibration for particular beam.
beamCalOffsets = [];                % Numeric [V]: Array of beam calibration offset voltages for each beam calibration channel
beamCalUseRejectedLight = false;    % Logical: Scalar or array indicating if rejected light (rather than transmitted light) for each beam's modulation device should be used to calibrate the transmission curve 