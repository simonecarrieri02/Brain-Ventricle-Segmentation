%-------------------------------------------------------
%                   FINAL EXAM PIM
%                   SIMONE CARRIERI
%                   UB, A.YEAR: 2025/2026
%-------------------------------------------------------
% This script performs automatic segmentation of brain ventricles
% from PD and T2 MRI images. The workflow includes:
% 1. Loading and preprocessing images (contrast enhancement + resizing)
% 2. Image fusion (weighted combination of PD and T2)
% 3. Ventricle segmentation using k-means clustering
% 4. Morphological cleaning to remove noise and refine the mask
% 5. Overlaying the ventricle boundaries on the original images
% 6. Saving the results and computing Jaccard index for validation
%
% Decisions made:
% - Weighted fusion (0.3 PD, 0.7 T2) based on prior testing of contrast
%   to enhance ventricle visibility in T2 images.
% - K-means with 4 clusters, selecting the brightest cluster as ventricles.
% - Morphological opening and erosion to remove small artifacts.
% - Jaccard index computed only for image 18 (reference available).

clc;
clear all;
close all;

%% -------------------- Paths Setup --------------------
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

% Fusion weights for the multimodal combination of PD and T2 images
params.fusion_weights = [0.5, 0.5];

% Morphological structuring elements
params.SE_open_radius  = 7;  % Radius for opening operations
params.SE_erode_radius = 3;          % Radius for erosion operations

params.num_classes_k = 4; %Number of k means classes

params.show=true;
params.save_results = true;


%% ----------------------- Save controls ----------------------

% Prepare summary table for Jaccard indices
summary = table('Size',[numel(params.img_range), 3], ...
                'VariableTypes', {'double','string','double'}, ...
                'VariableNames', {'Slice','Folder','Jaccard'});
rowIdx = 0;
cmap = lines(params.num_classes_k);

%% ----------------------- Load or generate ROI masks --------------------
roi_masks = load_or_generate_masks(path_images, params.img_range, ...
    params.min_area_pixels, params.show);

%% ----------------------- Processing of the images ----------------------
for k = 1:numel(params.img_range)
    slice_idx = params.img_range(k);
    rowIdx = rowIdx+1;
    roi_mask  = roi_masks{k};  % corresponding mask

    fprintf('\nProcessing slice %d...\n', slice_idx);
    
    % --- Load and preprocess images ---
    % Contrast enhancement, resize and conversiion to uint8.
    
    I_PD_orig = imread(fullfile(path_images,sprintf('ima%dPD.pgm',slice_idx))); %uint16
    I_T2_orig = imread(fullfile(path_images,sprintf('ima%dT2.pgm',slice_idx))); %uint16

    % Intensity adjustment and resizing to mask size
    roi_size = size(roi_mask);

    % % --- Plot (Original) ---
    % figure('Name', sprintf('Original Images - Slice %d', idx), 'NumberTitle', 'off');
    % 
    % % --- Subplot 1: PD ---
    % subplot(1,2,1);
    % imshow(I_PD_orig, []);
    % title(sprintf('PD Original (Slice %d)', idx));
    % 
    % % --- Subplot 2: T2 ---
    % subplot(1,2,2);
    % imshow(I_T2_orig, []);
    % title(sprintf('T2 Original (Slice %d)', idx));

    I_PD_adj = imadjust(I_PD_orig); %uint16
    I_T2_adj = imadjust(I_T2_orig); %uint16
    
    I_PD_uint8 = imresize(uint8(255*mat2gray(I_PD_adj)), roi_size); %uint8
    I_T2_uint8 = imresize(uint8(255*mat2gray(I_T2_adj)), roi_size); %uint8

       
    % % --- Histogram (Original vs Adjusted) ---
    % figure('Name', sprintf('Histogram Original vs Adjusted - Slice %d', idx), 'NumberTitle', 'off');
    % 
    % % --- PD Histograms (Original vs Adjusted) ---
    % subplot(1,2,1)
    % histogram(I_PD_adj,255,'FaceColor',[0.8500 0.3250 0.0980],'EdgeColor','none'); 
    % hold on
    % histogram(I_PD_orig,255,'FaceColor',[0 0.4470 0.7410],'EdgeColor','none');
    % title(sprintf('PD Image: Original vs After imadjust (Slice %d)', idx))
    % xlabel('Intensity Value')
    % ylabel('Pixel Count')
    % legend('After imadjust','Original')
    % grid on
    % ylim([0 3000])
    % hold off
    % 
    % % --- T2 Histograms (Original vs Adjusted) ---
    % subplot(1,2,2)
    % histogram(I_T2_adj,255,'FaceColor',[0.8500 0.3250 0.0980],'EdgeColor','none'); 
    % hold on
    % histogram(I_T2_orig,255,'FaceColor',[0 0.4470 0.7410],'EdgeColor','none');
    % title(sprintf('T2 Image: Original vs After imadjust (Slice %d)', idx))
    % xlabel('Intensity Value')
    % ylabel('Pixel Count')
    % legend('After imadjust','Original')
    % grid on
    % ylim([0 3000])
    % hold off

    % % --- Plot (Original vs Adjusted vs Resized) ---
    % figure('Name', sprintf('PD Original vs Adjusted VS Resized - Slice %d', idx), 'NumberTitle', 'off');
    % 
    % subplot(1,3,1)
    % imshow(I_PD_orig, [])
    % title('PD Original (256x256)','FontWeight','bold')
    % 
    % subplot(1,3,2)
    % imshow(I_PD_adj, [])
    % title('PD Adjusted (256x256)','FontWeight','bold')
    % 
    % subplot(1,3,3)
    % imshow(I_PD_uint8, [])
    % title('PD Adjusted & Resized (512x512)','FontWeight','bold')
    % 
    % 
    % % --- Figure for T2 images ---
    % figure('Name', sprintf('T2 Original vs Adjusted VS Resized - Slice %d', idx), 'NumberTitle', 'off');
    % 
    % subplot(1,3,1)
    % imshow(I_T2_orig, [])
    % title('T2 Original (256x256)','FontWeight','bold')
    % 
    % subplot(1,3,2)
    % imshow(I_T2_adj, [])
    % title('T2 Adjusted (256x256)','FontWeight','bold')
    % 
    % subplot(1,3,3)
    % imshow(I_T2_uint8, [])
    % title('T2 Adjusted & Resized (512x512)','FontWeight','bold')


    % --- Image Fusion ---
    % Role: Combine information from PD and T2 to enhance ventricles.
    % Decision: Weighted fusion with 0.5 PD and 0.5 T2 based on visibility.
    fused = uint8(round( ...
            double(I_T2_uint8) * params.fusion_weights(1) + ...
            double(I_PD_uint8) * params.fusion_weights(2) ...
          ));

    % % --- Plot (Original PD, T2, and Fused Image) ---
    % figure('Name', sprintf('Slice %d — Original PD, Original T2, and Fused Image', slice_idx), ...
    %        'NumberTitle', 'off');
    % 
    % subplot(1,3,1);
    % imshow(I_PD_uint8);
    % title('Original PD', 'FontWeight','bold');
    % 
    % subplot(1,3,2);
    % imshow(I_T2_uint8);
    % title('Original T2', 'FontWeight','bold');
    % 
    % subplot(1,3,3);
    % imshow(fused);
    % title('Fused PD + T2', 'FontWeight','bold');
    
    % % --- Histogram (Original vs Fused) ---
    % figure('Name', sprintf('Histogram Original vs Fused - Slice %d', idx), 'NumberTitle','off');
    % 
    % % Histogram: PD
    % subplot(1,2,1);
    % histogram(I_PD_uint8, 256, 'FaceColor', [0 0.4470 0.7410], 'EdgeColor', 'none');
    % hold on;
    % histogram(fused, 256, 'FaceColor', [0.8500 0.3250 0.0980], 'EdgeColor', 'none');
    % title('PD: Original vs Fused', 'FontWeight','bold');
    % xlabel('Intensity');
    % ylabel('Pixel Count');
    % legend('Original PD', 'Fused PD+T2');
    % grid on;
    % ylim([0 5000]);
    % hold off;
    % 
    % % Histogram: T2
    % subplot(1,2,2);
    % histogram(I_T2_uint8, 256, 'FaceColor', [0 0.4470 0.7410], 'EdgeColor', 'none');
    % hold on;
    % histogram(fused, 256, 'FaceColor', [0.8500 0.3250 0.0980], 'EdgeColor', 'none');
    % title('T2: Original vs Fused', 'FontWeight','bold');
    % xlabel('Intensity');
    % ylabel('Pixel Count');
    % legend('Original T2', 'Fused PD+T2');
    % grid on;
    % ylim([0 5000]);
    % hold off;
    % 
    % sgtitle(sprintf('Slice %d — Histogram Comparison', idx), 'FontWeight','bold');


    % --- Ventricle Segmentation ---
    % Role: Identify ventricle region using intensity clustering (k-means).
    % Decision: 4 clusters; the brightest cluster corresponds to ventricles.
    [L,cluster_means] = segment_ventricles(fused, params.num_classes_k);


    % Identify the brightest cluster (ventricles) 
    [~, ventricle_cluster] = max(cluster_means);

    % Generate binary mask for ventricles
    ventricle_mask = (L == ventricle_cluster);

    % % --- Plot (Cluster Overlay) ---
    % fig1 = figure('Name', sprintf('Slice %d — Cluster Overlay', slice_idx), ...
    %              'NumberTitle','off','Color','w','Units','pixels','Position',[100 100 1000 500]);
    % 
    % % 2) Cluster label overlay
    % imshow(labeloverlay(fused, L, 'Colormap', lines(params.num_classes_k), 'Transparency',0.6));
    % title('Cluster Map Overlay','FontWeight','bold');
    
    
    % % --- Histogram  (Fused Image with Cluster Means) ---
    % fig2 = figure('Name', sprintf('Slice %d — Cluster Histogram', slice_idx), ...
    %               'NumberTitle','off','Color','w','Units','pixels','Position',[100 100 1000 500]);
    % 
    % histogram(double(fused(:)), 256, 'FaceColor',[0.7 0.7 0.7],'EdgeColor','none');
    % hold on;
    % yL = ylim;
    % for c = 1:params.num_classes_k
    %     if c == ventricle_cluster
    %         plot([cluster_means(c) cluster_means(c)], yL, 'r-', 'LineWidth', 2);
    %     else
    %         plot([cluster_means(c) cluster_means(c)], yL, 'k--', 'LineWidth', 1);
    %     end
    % end
    % hold off;
    % xlabel('Intensity'); ylabel('Pixel Count');
    % title(sprintf('Cluster Means — Slice %d', slice_idx),'FontWeight','bold');
    % legend('Pixel Histogram','Ventricle Cluster','Other Clusters','Location','northeast');
    % ylim([0,4000])
    % grid on;

    
    % --- Morphological Cleaning ---
    % Role: Remove small noise, fill holes, and refine the ventricle mask.
    % Decision: Opening (disk radius 7) removes small bright spots.
    % Erosion (disk radius 3) smooths boundaries. Small areas <800 pixels removed.

    SE_open = strel('disk', params.SE_open_radius);
    SE_erode = strel('disk', params.SE_erode_radius);
    BW = imopen(ventricle_mask, SE_open);
    BW = imerode(BW, SE_erode);
    BW = imfill(BW,'holes');
    ventricle_mask_clean = bwareaopen(BW,800);
    
    % --- Overlay results ---
    % Role: Visual assessment by overlaying mask boundaries on original images.
    overlay_PD = imoverlay(I_PD_uint8, bwperim(ventricle_mask_clean), [1 0 0]);
    overlay_T2 = imoverlay(I_T2_uint8, bwperim(ventricle_mask_clean), [1 0 0]);


    % --- Validation (Jaccard) for all slices ---
    J = NaN;
    intersection = sum(ventricle_mask_clean & roi_mask, 'all');
    union_area   = sum(ventricle_mask_clean | roi_mask, 'all');
    if union_area > 0
        J = intersection / union_area;
    end

    % store summary row info
    summary.Slice(rowIdx) = slice_idx;
    summary.Folder(rowIdx) = string(sprintf('slice_%02d', slice_idx));
    summary.Jaccard(rowIdx) = J;
    
    % ---------- Display results -------------------------------------------
    if isfield(params,'show') && params.show
        hfig = figure('Name', sprintf('Slice %d', slice_idx), 'NumberTitle','off');
        subplot(2,3,1); imshow(I_T2_uint8); title('T2 (uint8)','FontWeight','bold');
        subplot(2,3,2); imshow(I_PD_uint8); title('PD (uint8)','FontWeight','bold');
        subplot(2,3,3); imshow(labeloverlay(fused, L, 'Colormap', lines(params.num_classes_k), 'Transparency',0.6));...
            title('Cluster Map Overlay','FontWeight','bold');
        subplot(2,3,4); imshow(ventricle_mask); title('Raw segmentation','FontWeight','bold');
        subplot(2,3,5); imshow(ventricle_mask_clean); title('Cleaned mask','FontWeight','bold');
        subplot(2,3,6); imshow(overlay_T2); title('Overlay on T2','FontWeight','bold');

        if ~isnan(J)
            sgtitle(sprintf('Slice %d — Jaccard = %.4f', slice_idx, J),'FontWeight','bold');
        else
            sgtitle(sprintf('Slice %d', slice_idx),'FontWeight','bold');
        end
    end

    % ---------- Save key results for the slice -----------------------
    if params.save_results
        slice_dir = fullfile(results_dir, sprintf('slice_%02d', slice_idx));
        if ~exist(slice_dir,'dir')
            mkdir(slice_dir);
        end
    
        % 1) Save fused image (uint8)
        imwrite(fused, fullfile(slice_dir,sprintf('auto_fused%02d.png',slice_idx)));
    
        % 2) Save raw ventricle mask
        imwrite(uint8(ventricle_mask)*255, fullfile(slice_dir,sprintf('auto_ventricle_mask_raw%02d.png',slice_idx)));
    
        % 3) Save cleaned ventricle mask
        imwrite(uint8(ventricle_mask_clean)*255, fullfile(slice_dir,sprintf('auto_ventricle_mask_clean%02d.png',slice_idx)));
    
        % 4) Save overlay on T2
        overlay_T2 = imoverlay(I_T2_uint8, bwperim(ventricle_mask_clean), [1 0 0]);
        imwrite(overlay_T2, fullfile(slice_dir,sprintf('auto_overlay_T2%02d.png',slice_idx)));
    
        % 5) Save cluster overlay
        L_normalized = zeros(size(L));
        L_normalized(L == ventricle_cluster) = 1;
        
        other_labels = setdiff(1:params.num_classes_k, ventricle_cluster);
        for i = 1:numel(other_labels)
            L_normalized(L == other_labels(i)) = i+1;
        end
        overlay_clusters = labeloverlay(fused, L_normalized, 'Colormap', cmap, 'Transparency', 0.6);
        imwrite(overlay_clusters, fullfile(slice_dir, sprintf('auto_overlay_clusters%02d.png', slice_idx)));

    
        % 6) Save all data in a .mat file
        save(fullfile(slice_dir,sprintf('auto_results_slice%02d.mat', slice_idx)), ...
             'summary','I_T2_uint8','I_PD_uint8','fused', ...
             'ventricle_mask','ventricle_mask_clean','overlay_T2','overlay_clusters');
    end

    
end

