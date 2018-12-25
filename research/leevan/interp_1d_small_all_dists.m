% Numerical results for different distributions on a small problem

% This is a function that helps for plotting confidence intervals
fill_between_lines = @(X,Y1,Y2,C) fill( [X fliplr(X)],  [Y1 fliplr(Y2)], C);

clf reset
fontsize = 14;
N = 31;
vvec = logspace(0, 2, 20) - 1 + .1;
x = pickpoints(-1, 1, N);
xeval = pickpoints(-1, 1, 100);
DM = DistanceMatrix(x, x);
DMeval = DistanceMatrix(xeval, x);
rbf = @(r) exp(-r.^2);
num_runs = 250;

stuff = { ...
    {'loocv', @(x) sin(6 * x) - x}, ...
    {'mle', @(x) 1 - tanh(3 * x) + exp(x)}, ...
    {'acc', @(x) 1 ./ (1 + 25 * (x - .3) .^ 2)}, ...
    };

for k=1:length(stuff)
    strat = stuff{k}{1};
    yf = stuff{k}{2};
    
    t_med_lu = zeros(1, length(vvec));
    t_bot_lu = zeros(1, length(vvec));
    t_top_lu = zeros(1, length(vvec));
    t_med_ln = zeros(1, length(vvec));
    t_bot_ln = zeros(1, length(vvec));
    t_top_ln = zeros(1, length(vvec));
    t_med_c2 = zeros(1, length(vvec));
    t_bot_c2 = zeros(1, length(vvec));
    t_top_c2 = zeros(1, length(vvec));
    t_med_ga = zeros(1, length(vvec));
    t_bot_ga = zeros(1, length(vvec));
    t_top_ga = zeros(1, length(vvec));
    j = 1;
    
    y = yf(x);
    yeval = yf(xeval);
    opt = struct('strat', strat, 'output', 'opt', 'svd_tol', 1e-13, 'xeval', xeval, 'yeval', yeval);
    bounds = [.001, 100];
    ep = choose_ep_rand(x, y, rbf, bounds, opt);
    
    ypred = rbf(ep * DMeval) * random_svd_solve(rbf(ep * DM), y);
    base_acc = errcompute(ypred, yeval);
    
    vcount = 1;
    for v=vvec
        results_uniform = zeros(1, num_runs);
        results_normal = zeros(1, num_runs);
        results_chi2 = zeros(1, num_runs);
        results_ga = zeros(1, num_runs);
        for m=1:num_runs
            % Log-uniform
            t = fzero(invt(v, ep), [.00001, .9999]);
            nu = 2 * ep * log(t) / (t - 1 / t);
            invt = @(v,m) (@(t) log(t) .* (t + 1./t)./(t - 1./t) - 1 - v/m^2);
            epvec = exp(pickpoints(log(nu / t), log(nu * t), N, 'rand'))';
            ypred_rnd = rbf(bsxfun(@times, DMeval, epvec)) * random_svd_solve(rbf(bsxfun(@times, DM, epvec)), y);
            results_uniform(m) = errcompute(ypred_rnd, yeval);
            
            % Log-normal
            sigma = sqrt(log(v / ep^2 + 1));
            mu = log(ep^2 / sqrt(v + ep^2));
            epvec = lognrnd(mu, sigma, 1, N);
            ypred_rnd = rbf(bsxfun(@times, DMeval, epvec)) * random_svd_solve(rbf(bsxfun(@times, DM, epvec)), y);
            results_normal(m) = errcompute(ypred_rnd, yeval);
            
            % Chi-squared
            epvec = chi2rnd(ep, 1, N);
            ypred_rnd = rbf(bsxfun(@times, DMeval, epvec)) * random_svd_solve(rbf(bsxfun(@times, DM, epvec)), y);
            results_chi2(m) = errcompute(ypred_rnd, yeval);
            
            % Gamma
            a = ep^2 / v;
            b = v / ep;
            epvec = gamrnd(a, b, 1, N);
            ypred_rnd = rbf(bsxfun(@times, DMeval, epvec)) * random_svd_solve(rbf(bsxfun(@times, DM, epvec)), y);
            results_ga(m) = errcompute(ypred_rnd, yeval);
        end
        t_bot_lu(vcount) = prctile(results_uniform, 25);
        t_med_lu(vcount) = prctile(results_uniform, 50);
        t_top_lu(vcount) = prctile(results_uniform, 75);
        t_bot_ln(vcount) = prctile(results_normal, 25);
        t_med_ln(vcount) = prctile(results_normal, 50);
        t_top_ln(vcount) = prctile(results_normal, 75);
        t_bot_c2(vcount) = prctile(results_chi2, 25);
        t_med_c2(vcount) = prctile(results_chi2, 50);
        t_top_c2(vcount) = prctile(results_chi2, 75);
        t_bot_ga(vcount) = prctile(results_ga, 25);
        t_med_ga(vcount) = prctile(results_ga, 50);
        t_top_ga(vcount) = prctile(results_ga, 75);
        vcount = vcount + 1;
    end
    
    subplot(1, length(stuff), k)
    hfill = fill_between_lines(vvec, t_bot_lu, t_top_lu, 'r');
    hold on
    set(hfill, 'linestyle', 'none')
    set(hfill, 'facealpha', .2)
    plot(vvec, t_med_lu, 'r', 'linewidth', 3)
    plot(vvec, t_bot_lu, ':r', 'linewidth', 2)
    plot(vvec, t_top_lu, ':r', 'linewidth', 2)
    plot(vvec, t_med_ln, 'b', 'linewidth', 3)
    plot(vvec, t_bot_ln, ':b', 'linewidth', 2)
    plot(vvec, t_top_ln, ':b', 'linewidth', 2)
    plot(vvec, t_med_c2, 'g', 'linewidth', 3)
    plot(vvec, t_bot_c2, ':g', 'linewidth', 2)
    plot(vvec, t_top_c2, ':g', 'linewidth', 2)
    plot(vvec, t_med_ga, 'm', 'linewidth', 3)
    plot(vvec, t_bot_ga, ':m', 'linewidth', 2)
    plot(vvec, t_top_ga, ':m', 'linewidth', 2)
    hsol = plot(vvec, base_acc * ones(1, length(vvec)), '--k', 'linewidth', 3);
    set(gca, 'xscale', 'log')
    set(gca, 'yscale', 'log')
%     xlim([1, 10])
%     ylim([1e-9, 1e0])
    xlabel('$\tau$', 'fontsize', fontsize, 'interpreter', 'latex')
    ylabel('RMSE', 'fontsize', fontsize)
    xticks([1, 10])
    yticks([1e-8, 1e-4, 1e0])
    set(gca, 'fontsize', fontsize)
    legend([hsol, hfill], {sprintf('$\\varepsilon=%3.2f$', ep), 'random'}, ...
        'location', 'northwest', 'interpreter', 'latex', 'fontsize', fontsize)
    hold off
    
    j = j + 1;
end

% savefig('examples_1d_TINY')
% saveas(gcf, 'examples_1d_TINY', 'png')