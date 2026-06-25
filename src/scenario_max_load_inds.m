function result = scenario_max_load_inds(scenario) % Find scenario indices for maximum load per zone
    rs = reshape(scenario(:, end), 6, []);
    result = find(rs == max(rs, [], 2));
end