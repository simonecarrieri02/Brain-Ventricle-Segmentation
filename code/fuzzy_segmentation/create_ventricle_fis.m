function fis = create_ventricle_fis()
% CREATE_VENTRICLE_FIS  Create a Mamdani FIS for ventricle likelihood
%
%   Syntax:
%       fis = create_ventricle_fis()
%
%   Description:
%       Builds and returns a mamfis object configured to estimate the
%       likelihood that a pixel belongs to the ventricle. Inputs are
%       normalized to the range [0 1]. The FIS uses three inputs:
%           1) T2       - T2 intensity (normalized)
%           2) GradMag  - gradient magnitude (normalized)
%           3) DistCenter - normalized distance-to-center (1 = center)
%       The single output is:
%           VentricleLikelihood (range [0 1]) with four overlapping MFs.
%
%   Inputs:
%       none
%
%   Outputs:
%       fis  - mamfis object with inputs, membership functions and rules
%
%   Author : Simone Carrieri
%   Date   : 2025
%   Notes  : This function only defines the FIS structure; evaluation is
%            performed with evalfis(fis, data).

    % Create base FIS
    fis = mamfis('Name', 'ventricle_rules');

    % ---------------------- Inputs (range [0 1]) -------------------------
    fis = addInput(fis, [0 1], 'Name', 'T2');
    fis = addInput(fis, [0 1], 'Name', 'GradMag');
    fis = addInput(fis, [0 1], 'Name', 'DistCenter');

    % ---------------------- Membership functions -------------------------
    % T2 (four overlapping levels)
    fis = addMF(fis, 'T2', 'trapmf', [0   0   0.25 0.45], 'Name', 'Low');       % lower region
    fis = addMF(fis, 'T2', 'trimf',  [0.35 0.5 0.65],    'Name', 'Med');       % medium
    fis = addMF(fis, 'T2', 'trimf',  [0.55 0.78 0.92],   'Name', 'High');      % slightly wider
    fis = addMF(fis, 'T2', 'trapmf', [0.88 0.92 1    1   ], 'Name', 'VeryHigh'); % upper region

    % GradMag (edge strength, overlapping)
    fis = addMF(fis, 'GradMag', 'trapmf', [0    0    0.04 0.10], 'Name', 'Low');
    fis = addMF(fis, 'GradMag', 'trimf',  [0.08 0.15 0.25],      'Name', 'Med');
    fis = addMF(fis, 'GradMag', 'trapmf', [0.20 0.30 1    1   ], 'Name', 'High');

    % DistCenter (1 = near center), overlapping
    fis = addMF(fis, 'DistCenter', 'trapmf', [0    0    0.25 0.55], 'Name', 'Far');
    fis = addMF(fis, 'DistCenter', 'trimf',  [0.45 0.60 0.75],      'Name', 'Mid');
    fis = addMF(fis, 'DistCenter', 'trapmf', [0.65 0.80 1    1   ], 'Name', 'Near');

    % ---------------------- Output: VentricleLikelihood ------------------
    fis = addOutput(fis, [0 1], 'Name', 'VentricleLikelihood');
    fis = addMF(fis, 'VentricleLikelihood', 'trapmf', [0    0    0.25 0.45], 'Name', 'Low');
    fis = addMF(fis, 'VentricleLikelihood', 'trimf',  [0.35 0.50 0.65],      'Name', 'Low-Med');
    fis = addMF(fis, 'VentricleLikelihood', 'trimf',  [0.55 0.70 0.85],      'Name', 'Med-High');
    fis = addMF(fis, 'VentricleLikelihood', 'trapmf', [0.75 0.90 1    1   ], 'Name', 'High');

    % ---------------------- Rule base -----------------------------------
    % Rules format: [T2 GradMag DistCenter Output Weight Conn]
    % conn = 1 (AND). Weight in [0,1].
    rules = [
        % ----- STRONG (T2-driven) ---------------------------------------
        3 0 0 3 1    1    % IF T2 High THEN Med-High
        4 0 0 4 1    1    % IF T2 VeryHigh THEN High

        % ----- MORE CERTAINTY: T2 high + favorable context --------------
        3 1 3 4 0.98 1    % IF T2 High AND GradMag Low  AND DistCenter Near THEN High
        3 2 3 4 0.95 1    % IF T2 High AND GradMag Med  AND DistCenter Near THEN High
        3 1 2 3 0.90 1    % IF T2 High AND GradMag Low  AND DistCenter Mid  THEN Med-High

        % ----- MEDIUM (T2 medium) --------------------------------------
        2 0 0 2 0.85 1    % IF T2 Med THEN Low-Med
        2 1 2 2 0.75 1    % IF T2 Med AND GradMag Low AND DistCenter Mid THEN Low-Med
        2 1 3 1 1    1    % IF T2 Med AND GradMag Low AND DistCenter Near THEN Low

        % ----- NEGATIVE EVIDENCE ---------------------------------------
        1 0 0 1 1    1    % IF T2 Low THEN Low
        0 3 0 1 0.6  1    % IF GradMag High THEN Low (edge -> likely not ventricle)
        0 0 1 1 0.6  1    % IF DistCenter Far THEN Low

        % ----- SAFETY / MIXED -------------------------------------------
        3 0 2 3 0.7  1    % IF T2 High AND GradMag Med THEN Med-High
        2 2 0 2 0.6  1    % IF T2 Med AND GradMag Med THEN Low-Med
    ];

    % Add rules to fis
    fis = addRule(fis, rules);

    % ---------------------- (Optional) FIS settings ---------------------
    % Keep default defuzzification / aggregation methods (centroid / max / min)
    % Uncomment to explicitly set:
    % fis.DefuzzificationMethod = 'centroid';
    % fis.AggregationMethod    = 'max';
    % fis.AndMethod            = 'min';
    % fis.OrMethod             = 'max';
end
