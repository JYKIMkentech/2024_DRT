function [gamma_lower, gamma_upper, gamma_resample_all] = bootstrap_uncertainty(t, ik, V_sd, lambda, n, dt, dur, OCV, R0, num_resamples)
    % bootstrap_uncertainty estimates the uncertainty of gamma using bootstrap resampling.
    %
    % Inputs:
    %   t             - Time vector
    %   ik            - Current vector
    %   V_sd          - Measured voltage vector
    %   lambda        - Regularization parameter
    %   n             - Number of RC elements
    %   dt            - Sampling time
    %   dur           - Duration (tau_max)
    %   OCV           - Open Circuit Voltage
    %   R0            - Initial resistance
    %   num_resamples - Number of bootstrap resamples
    %
    % Outputs:
    %   gamma_lower        - Lower bound of gamma estimate (5th percentile)
    %   gamma_upper        - Upper bound of gamma estimate (95th percentile)
    %   gamma_resample_all - All resampled gamma estimates

    % Original gamma estimate
    [gamma_original, ~, theta_discrete, tau_discrete, ~] = DRT_estimation(t, ik, V_sd, lambda, n, dt, dur, OCV, R0);
    delta_theta = theta_discrete(2) - theta_discrete(1);

    % Regularization matrix L (first-order difference)
    L = zeros(n-1, n);
    for i = 1:n-1
        L(i, i) = -1;
        L(i, i+1) = 1;
    end

    % Inequality constraints
    A_ineq = -eye(n);
    b_ineq = zeros(n, 1);

    % Quadprog options
    options = optimoptions('quadprog', 'Display', 'off');

    % Initialize matrix to store resampled gamma estimates
    gamma_resample_all = zeros(num_resamples, n);

    for b = 1:num_resamples
        % Resample indices with replacement
        resample_idx = randsample(length(t), length(t), true);

        % Resampled data
        t_resampled = t(resample_idx);
        ik_resampled = ik(resample_idx);
        V_sd_resampled = V_sd(resample_idx);

        % Remove duplicates and sort
        [t_resampled_unique, unique_idx] = unique(t_resampled);
        ik_resampled_unique = ik_resampled(unique_idx);
        V_sd_resampled_unique = V_sd_resampled(unique_idx);
        [t_resampled_sorted, sort_idx] = sort(t_resampled_unique);
        ik_resampled_sorted = ik_resampled_unique(sort_idx);
        V_sd_resampled_sorted = V_sd_resampled_unique(sort_idx);

        % Recalculate dt_resampled
        dt_resampled = [t_resampled_sorted(1); diff(t_resampled_sorted)];

        % Recompute W_resampled
        W_resampled = zeros(length(t_resampled_sorted), n);
        for k_idx = 1:length(t_resampled_sorted)
            if k_idx == 1
                for i = 1:n
                    W_resampled(k_idx, i) = ik_resampled_sorted(k_idx) * ...
                        (1 - exp(-dt_resampled(k_idx) / tau_discrete(i))) * delta_theta;
                end
            else
                for i = 1:n
                    W_resampled(k_idx, i) = W_resampled(k_idx-1, i) * exp(-dt_resampled(k_idx) / tau_discrete(i)) + ...
                        ik_resampled_sorted(k_idx) * (1 - exp(-dt_resampled(k_idx) / tau_discrete(i))) * delta_theta;
                end
            end
        end

        % Adjusted y_resampled
        y_adjusted_resampled = V_sd_resampled_sorted - OCV - R0 * ik_resampled_sorted;

        % Quadratic programming matrices
        H_resampled = 2 * (W_resampled' * W_resampled + lambda * (L' * L));
        f_resampled = -2 * W_resampled' * y_adjusted_resampled;

        % Solve quadratic programming problem
        gamma_resample = quadprog(H_resampled, f_resampled, A_ineq, b_ineq, [], [], [], [], [], options);

        % Store resampled gamma
        gamma_resample_all(b, :) = gamma_resample';
    end

    % Calculate percentiles (5% and 95%)
    gamma_resample_percentiles = prctile(gamma_resample_all - gamma_original', [5 95]);
    %gamma_resample_percentiles = prctile(gamma_resample_all, [5 95]);

    % Uncertainty bounds
    gamma_lower = gamma_original' + gamma_resample_percentiles(1, :);
    gamma_upper = gamma_original' + gamma_resample_percentiles(2, :);
end
