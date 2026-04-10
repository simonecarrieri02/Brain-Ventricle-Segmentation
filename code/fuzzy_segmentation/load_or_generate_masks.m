function roi_masks = load_or_generate_masks(path_images, slices, min_area_pixels, show)
%LOAD_OR_GENERATE_MASKS Load ROI masks or generate manual masks for given slices
%
%   roi_masks = load_or_generate_masks(path_images, slices, min_area_pixels, show)
%
%   Inputs:
%       path_images      - path to folder containing images
%       slices           - vector of slice indices to process
%       min_area_pixels  - minimum connected area to keep in mask
%       show             - boolean, whether to display figures
%
%   Output:
%       roi_masks        - cell array of masks for each slice in `slices`

    % Ensure mask folder exists
    mask_dir = fullfile(path_images, 'mask');
    if ~exist(mask_dir, 'dir')
        mkdir(mask_dir);
    end

    roi_masks = cell(size(slices));

    for k = 1:numel(slices)
        slice_idx = slices(k);

        % ---------- Slice 18: ground truth --------------------------------
        if slice_idx == 18
            roi_mask_file = fullfile(mask_dir, 'roimask_vent_18_T2.pgm');
            if isfile(roi_mask_file)
                roi_img      = imread(roi_mask_file);
                roi_boundary = (roi_img(:,:,1) ~= roi_img(:,:,2)) | ...
                               (roi_img(:,:,1) ~= roi_img(:,:,3));
                roi_mask     = imfill(roi_boundary, 'holes');
                fprintf('Loaded existing manual mask for slice 18.\n');
            else
                warning('ROI mask for slice 18 not found: %s', roi_mask_file);
                roi_mask = zeros(512,512); % fallback blank mask
            end
            roi_masks{k} = roi_mask;
            continue;
        end

        % ---------- Other slices ------------------------------------------
        mask_file = fullfile(mask_dir, sprintf('roimask_vent_%d_T2.pgm', slice_idx));
        if isfile(mask_file)
            mask = imread(mask_file) > 0;
            fprintf('Loaded existing manual mask for slice %d.\n', slice_idx);
        else
            % Load T2 image
            try
                I_T2_orig = imread(fullfile(path_images, sprintf('ima%dT2.pgm', slice_idx)));
            catch ME
                warning('Could not read T2 image for slice %d: %s', slice_idx, ME.message);
                roi_masks{k} = [];
                continue;
            end
            I_T2 = im2double(imresize(imadjust(I_T2_orig), [512 512]));

            % ---------- Manual mask drawing using points ----------------
            fprintf('Define ventricle mask for slice %d by clicking points. Double-click to finish.\n', slice_idx);
            fig=figure('Name', sprintf('Slice %d - Manual Mask', slice_idx), 'NumberTitle', 'off');
            imshow(I_T2, []);
            title('Click points to define ventricle ROI. Double-click to close polygon.', 'FontWeight', 'bold');

            mask = false(size(I_T2)); % default empty mask
            try
                h = impoly;
                position = wait(h);  % wait for user input
                if ~isempty(position)
                    mask = createMask(h);
                else
                    warning('No points selected: mask will be empty.');
                end
            catch
                warning('ROI creation cancelled or figure closed. Mask set to empty.');
            end
            
            if ishandle(fig)
                close(fig);
            end
            % Morphological cleanup
            mask = imfill(mask, 'holes');
            mask = bwareaopen(mask, min_area_pixels);

            % Display overlay
            if show
                figure('Name', sprintf('Slice %d - Overlay', slice_idx), 'NumberTitle', 'off');
                imshow(imoverlay(I_T2, bwperim(mask), [1 0 0]));
                title('Manual ventricle mask overlay', 'FontWeight', 'bold');
            end

            % Save mask
            imwrite(uint8(mask)*255, mask_file);
            fprintf('Manual mask saved: %s\n', mask_file);
            close all;
        end

        roi_masks{k} = mask;
    end
end
