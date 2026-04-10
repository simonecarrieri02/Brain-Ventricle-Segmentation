%-------------------------------------------------------
%                   FINAL EXAM PIM
%                   SIMONE CARRIERI
%                   UB, A.YEAR: 2025/2026
%-------------------------------------------------------


clc;
clear;
close all;

%% -------------------- Paths Setup --------------------
% Define the directory containing the input images and the results folder
path_images = fullfile('..', 'base_images');
results_dir = fullfile( 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end


%% -------------------- Experiment Parameters --------------------
% The 'params' structure encapsulates all critical parameters governing
% the segmentation pipeline

% Slices to be processed
params.img_range = [15, 18, 19, 20, 21];

% Minimum connected area (in pixels) to retain during morphological cleaning
params.min_area_pixels = 800;

params.show=true;


%% ----------------------- Save controls ----------------------

% Prepare summary table for Jaccard indices
summary = table('Size',[numel(params.img_range), 3], ...
                'VariableTypes', {'double','string','double'}, ...
                'VariableNames', {'Slice','Folder','Jaccard'});
rowIdx = 0;


%% ----------------------- Load or generate ROI masks --------------------
roi_masks = load_or_generate_masks(path_images, params.img_range, ...
                                   params.min_area_pixels, params.show);

%% ----------------------- Main processing loop -------------------------
for k = 1:numel(params.img_range)
    slice_idx = params.img_range(k);
    rowIdx = rowIdx + 1;
    roi_mask  = roi_masks{k};  % corresponding mask

    fprintf('\nProcessing slice %d...\n', slice_idx);

    % ---------- Load and preprocess images --------------------------------
    I_PD_orig = imread(fullfile(path_images, sprintf('ima%dPD.pgm', slice_idx))); %uint16
    I_T2_orig = imread(fullfile(path_images, sprintf('ima%dT2.pgm', slice_idx))); %uint16

    % Intensity adjustment and resizing to mask size
    roi_size = size(roi_mask);

    I_PD_adj=imadjust(I_PD_orig); %uint16
    I_T2_adj=imadjust(I_T2_orig); %uint16
    
    I_PD_uint8 = imresize(uint8(255*mat2gray(I_PD_adj)), roi_size); %uint8
    I_T2_uint8 = imresize(uint8(255*mat2gray(I_T2_adj)), roi_size); %uint8

    % ---------------------- Feature extraction ---------------------------
    
    %Intensity to double
    I_PD = im2double(I_PD_uint8);
    I_T2 = im2double(I_T2_uint8);

    % Gradient magnitude
    [GX, GY] = imgradientxy(I_T2, 'sobel');
    gradMag  = imgradient(GX, GY);
    gradMag  = mat2gray(gradMag);

    % Normalized distance-to-center (1 = center, 0 = far)
    [rows, cols] = size(I_T2);
    [X, Y] = meshgrid(1:cols, 1:rows);
    cx = (cols + 1) / 2;
    cy = (rows + 1) / 2;
    dist = sqrt((X - cx).^2 + (Y - cy).^2);
    distCenter = 1 - dist ./ max(dist(:));


    % % --- Plotting ---
    % figure('Color','w','Position',[100 100 1200 400]);
    % 
    % subplot(1,3,1);
    % imagesc(I_T2); axis image off; colormap gray;
    % title('Normalized Intensity (T2)', 'FontSize', 12);
    % 
    % subplot(1,3,2);
    % imagesc(gradMag); axis image off; colormap gray;
    % title('Gradient Magnitude', 'FontSize', 12);
    % 
    % subplot(1,3,3);
    % imagesc(distCenter); axis image off; colormap gray;
    % title('Normalized Distance from Center', 'FontSize', 12);
    % 
    % sgtitle('Feature Maps for Fuzzy Segmentation', 'FontSize', 14, 'FontWeight', 'bold');

    % ---------- Fuzzy segmentation: continuous likelihood map ---------------
    [ventricleLikelihoodMap, fis] = segment_ventricles_fuzzy_rules(I_T2, gradMag, distCenter);

    % ---------- Threshold (alpha-cut) ------------------------------------
    Vmap=mat2gray(ventricleLikelihoodMap);
    min_foreground_value = 0.16;
    foreground_pixels    = Vmap(Vmap > min_foreground_value);

    %Select the alpha-cut as the 86th percentile of the ventricleLikelihoodMap distribution
    p   = 86;
    thr = prctile(foreground_pixels, p);
    binaryMask = ventricleLikelihoodMap >= thr;

    % % --- Plotting ---
    % all_pixels = ventricleLikelihoodMap(:);            
    % 
    % % Combine data for boxplot
    % data = [all_pixels; foreground_pixels];
    % group = [ones(size(all_pixels)); 2*ones(size(foreground_pixels))];
    % 
    % % Plot boxplot
    % figure;
    % boxplot(data, group, 'Labels', {'Before Foreground Threshold', 'After Foreground Threshold'});
    % ylabel('Normalized Likelihood');
    % title('Boxplot of Ventricle Likelihood Map Before and After Applying Foreground Threshold');
    % grid on;

    % ---------- Morphological post-processing ------------------------------
    mask_clean = imfill(binaryMask, 'holes');
    mask_clean = bwareaopen(mask_clean, params.min_area_pixels);

    % --- Validation (Jaccard) for all slices ---
    J = NaN;
    intersection = sum(mask_clean & roi_mask, 'all');
    union_area   = sum(mask_clean | roi_mask, 'all');
    if union_area > 0
        J = intersection / union_area;
    end

    % store summary row info
    summary.Slice(rowIdx) = slice_idx;
    summary.Folder(rowIdx) = string(sprintf('slice_%02d', slice_idx));
    summary.Jaccard(rowIdx) = J;

    % ---------- Display results -------------------------------------------
    if params.show
        fig = figure('Name', sprintf('Slice %d', slice_idx), 'NumberTitle', 'off');

        subplot(2,3,1); imshow(I_T2, []); title('T2 (normalized)', 'FontWeight', 'bold');
        subplot(2,3,2); imshow(I_PD, []); title('PD (normalized)', 'FontWeight', 'bold');
        subplot(2,3,3); imagesc(ventricleLikelihoodMap); axis image off;
            title('Ventricle Likelihood (Vmap)', 'FontWeight', 'bold'); colorbar;
        subplot(2,3,4); imshow(binaryMask); title(sprintf('Raw mask (thr=%.3f)', thr), 'FontWeight', 'bold');
        subplot(2,3,5); imshow(mask_clean); title('Cleaned mask', 'FontWeight', 'bold');
        subplot(2,3,6); imshow(imoverlay(I_T2, bwperim(mask_clean), [1 0 0]));
            title('Overlay on T2', 'FontWeight', 'bold');

        if ~isnan(J)
            sgtitle(sprintf('Slice %d — Jaccard = %.4f', slice_idx, J));
        else
            sgtitle(sprintf('Slice %d', slice_idx));
        end
    end

    % ---------- Optional: save cleaned masks -------------------------------
    if params.show && ~isempty(mask_clean)
        % Create a subfolder for the current slice
        slice_dir = fullfile(results_dir, sprintf('slice_%02d', slice_idx));
        if ~exist(slice_dir, 'dir')
            mkdir(slice_dir);
        end
        
        % 1. Save ventricle likelihood map
        figV = figure('Visible','off');
        imagesc(ventricleLikelihoodMap); axis image off; colorbar;
        title('Ventricle Likelihood Map', 'FontWeight', 'bold');
        
        Vfile = fullfile(slice_dir, 'ventricleLikelihoodMap.png');
        exportgraphics(figV, Vfile, 'Resolution',300);  % salva con colori e colorbar
        close(figV);

        
        % 2. Save raw binary mask
        rawmask_file = fullfile(slice_dir, 'raw_mask.png');
        imwrite(uint8(binaryMask)*255, rawmask_file);
        
        % 3. Save cleaned mask
        cleanmask_file = fullfile(slice_dir, 'clean_mask.png');
        imwrite(uint8(mask_clean)*255, cleanmask_file);
        
        % 4. Save overlay
        overlay_img = imoverlay(I_T2, bwperim(mask_clean), [1 0 0]);
        overlay_file = fullfile(slice_dir, 'overlay.png');
        imwrite(overlay_img, overlay_file);
        
        % 5. Save all data in a .mat file for future use
        mat_file = fullfile(slice_dir, sprintf('fuzzy_results_slice%02d.mat', slice_idx));
        save(mat_file, 'summary','ventricleLikelihoodMap', 'binaryMask', 'mask_clean', 'overlay_img');

    end
end

% % --- Plot Membership Functions ---
% 
% input_names  = {fis.Inputs.Name};
% output_names = {fis.Outputs.Name};
% 
% %Plot inputs
% for i = 1:numel(input_names)
%     fig = figure('Name', sprintf('Input: %s', char(input_names{i})), ...
%                  'NumberTitle', 'off', 'Visible', 'on');
% 
%     % Plot the MFs of the i-th input
%     plotmf(fis, 'input', i);
% 
%     % Title and axes formatting
%     title(sprintf('Membership Functions — Input: %s', char(input_names{i})), ...
%           'FontWeight', 'bold', 'Interpreter', 'none');
%     xlabel('Normalized Input [0 1]');
%     ylabel('Membership Degree');
%     grid on;
% 
%     % Academic-style formatting
%     set(gca, 'FontSize', 11, 'Box', 'on');
%     drawnow;
% end
% 
% %Plot output
% for i = 1:numel(output_names)
%     fig = figure('Name', sprintf('Output: %s', char(output_names{i})), ...
%                  'NumberTitle', 'off', 'Visible', 'on');
% 
%     % Plot the MFs of the i-th output
%     plotmf(fis, 'output', i);
% 
%     % Title and axes formatting
%     title(sprintf('Membership Functions — Output: %s', char(output_names{i})), ...
%           'FontWeight', 'bold', 'Interpreter', 'none');
%     xlabel('Normalized Output [0 1]');
%     ylabel('Membership Degree');
%     grid on;
% 
%     % Academic-style formatting
%     set(gca, 'FontSize', 11, 'Box', 'on');
%     drawnow;
% end
