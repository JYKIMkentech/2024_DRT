function [noisy_I, states] = add_markov_noise(I_original, n, noise_percent, initial_state)
    % add_markov_noise - Adds Markov chain-based noise to current data
    %
    % Inputs:
    %   I_original    - Original current data (vector)
    %   n             - Number of states in the Markov chain (integer)
    %   noise_percent - Scaling factor for the noise (float)
    %   initial_state - Initial state (integer between 1 and n)
    %
    % Outputs:
    %   noisy_I       - Current data with added noise (vector)
    %   states        - Markov state at each time (vector)

    % Compute mean current and noise
    mean_I = mean(I_original);
    mean_noise = mean_I * noise_percent;

    % Compute min and max noise
    min_noise = min(I_original) * noise_percent;
    max_noise = max(I_original) * noise_percent;
    span = max_noise - min_noise;

    noise_vector = linspace(mean_noise - span/2, mean_noise + span/2, n);

    % Compute sigma for noise distribution
    sigma = span / 50;

    % Transition probability matrix
    P = zeros(n);

    for i = 1:n
        probabilities = normpdf(noise_vector, noise_vector(i), sigma);
        P(i, :) = probabilities / sum(probabilities);
    end

    % Initialize
    noisy_I = zeros(size(I_original));
    states = zeros(size(I_original));
    current_state = initial_state;

    for idx = 1:length(I_original)
        % Add noise
        noisy_I(idx) = I_original(idx) + noise_vector(current_state);

        % Record state
        states(idx) = current_state;

        % Transition to next state
        current_state = randsample(1:n, 1, true, P(current_state, :));
    end
end


