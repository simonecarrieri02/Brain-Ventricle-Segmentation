function [L, cluster_means] = segment_ventricles(fused_image, n_classes)
% SEGMENT_VENTRICLES Segments ventricles from a fused MRI image using k-means clustering.
%
% Syntax:
%   [L, cluster_means] = segment_ventricles(fused_image, n_classes)
%
% Inputs:
%   fused_image - uint8 fused image combining PD and T2 modalities
%   n_classes   - Number of clusters for k-means
%
% Outputs:
%   L            - Labeled image where each pixel is assigned a cluster [1..n_classes]
%   cluster_means - 1 x n_classes vector of mean intensity values for each cluster
%
% Rationale:
%   - K-means groups pixels into clusters of similar intensity.
%   - Ventricles are typically the brightest regions (CSF-filled) in the fused image.

    % --- Step 1: Apply k-means clustering ---
    % Labeled image: each pixel assigned to a cluster [1..n_classes]
    [L, ~] = imsegkmeans(fused_image, n_classes);

    % --- Step 2: Compute mean intensity of each cluster ---
    cluster_means = zeros(1, n_classes);
    for c = 1:n_classes
        cluster_pixels = fused_image(L == c);   % Pixels in cluster c
        cluster_means(c) = mean(cluster_pixels); % Mean intensity of cluster c
    end
end