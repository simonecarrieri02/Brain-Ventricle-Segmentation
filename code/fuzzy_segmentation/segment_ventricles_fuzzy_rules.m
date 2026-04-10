function [Vmap, fis] = segment_ventricles_fuzzy_rules(I_T2, gradMag, distCenter)
% SEGMENT_VENTRICLES_FUZZY_RULES  Evaluate a Mamdani FIS and return a
%                                 ventricle likelihood map.
%
%   Syntax:
%       [Vmap, fis] = segment_ventricles_fuzzy_rules(I_T2)
%
%   Description:
%       Computes per-pixel features from a T2-weighted image (gradient
%       magnitude and normalized distance-to-center), evaluates a
%       pre-defined Mamdani FIS and returns the continuous ventricle
%       likelihood map together with the constructed FIS object.
%
%   Inputs:
%       I_T2  - 2D grayscale T2-weighted image. Values will be scaled to [0,1].
%
%   Outputs:
%       Vmap  - (rows x cols) continuous ventricle likelihood map in [0,1].
%       fis   - mamfis object used for evaluation.
%
%   Example:
%       I_T2 = im2double(imread('ima18T2.pgm'));
%       [Vmap, fis] = segment_ventricles_fuzzy_rules(I_T2);
%       imshow(Vmap, []);
%
%   Author : Simone Carrieri
%   Date   : 2025


    % ---------------------- Build & evaluate FIS -------------------------
    fis = create_ventricle_fis();
    [rows, cols] = size(I_T2);

    % Prepare data: [T2, GradMag, DistCenter]
    N = rows * cols;
    data = [reshape(I_T2, N, 1), reshape(gradMag, N, 1), reshape(distCenter, N, 1)];

    % Evaluate FIS and reshape to image
    V = evalfis(fis, data);
    Vmap = reshape(V, rows, cols);

    % Clamp values to [0,1] for numerical stability
    %Vmap = max(0, min(1, Vmap));
end
