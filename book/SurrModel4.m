% SurrModel4.m
% This considers the development of a surrogate model for the empirical
% distribution function (EDF) of data drawn from a random distribution.
% The data we consider again comes from the carsmall data set, where we
% consider the probability of finding a car with a given set of
% Acceleration, Displacement, Horsepower and Weight values.
% We use this density to help us compute a marginal model, studying the
% relevance of the parameters Horsepower and Weight averaged over all
% possible Acceleration and Displacement values which occur with
% probability density defined through the ECDF surrogate model.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Idea - Is it possible to introduce a constraint into the optimization
%%% problem so that, for fixed epsilon, a mu can be found to minimize the
%%% residual subject to enforcing positivity of the PDF?  Maybe, we would
%%% need test points at which the positivity is enforced, and an
%%% approximation to the derivative which is linear (maybe).  I guess it
%%% could be nonlinear within fmincon
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Standardize the random results
global GAUSSQR_PARAMETERS
GAUSSQR_PARAMETERS.RANDOM_SEED(0);

% Define some RBFs for use on this problem
rbfM2 = @(r) (1+r).*exp(-r);
rbfM2dx = @(r,dx,ep) -ep^2*exp(-r).*dx;
rbfM2dxdy = @(r,dx,dy,ep) prod(ep.^2)*exp(-r).*dx.*dy./(r+eps);
rbfM4 = @(r) (3+3*r+r.^2).*exp(-r);
rbfM4dx = @(r,dx,ep) -ep^2*exp(-r).*(1+r).*dx;
rbfM4dxdy = @(r,dx,dy,ep) prod(ep.^2)*exp(-r).*dx.*dy;
rbfM6 = @(r) (15+15*r+6*r.^2+r.^3).*exp(-r);
rbfM6dx = @(r,dx,ep) -ep^2*exp(-r).*(r.^2+3*r+3).*dx;
rbfM6dxdy = @(r,dx,dy,ep) prod(ep.^2)*exp(-r).*dx.*dy.*(1+r);

% This function allows you to evaluate the EDF
% Here, xe are the evaluation points, x are the observed locations
Fhat = @(xe,x) reshape(sum(all(repmat(x,[1,1,size(xe,1)])<=repmat(reshape(xe',[1,size(xe,2),size(xe,1)]),[size(x,1),1,1]),2),1),size(xe,1),1)/size(x,1);

% Choose the problem you want to study by setting test_opt
%   1 - 1D CDF fit to a generalized Pareto distribution
%   2 - 2D CDF fit to a normal distribution
%   3 - 4D CDF fit to carsmall data
test_opt = 1;

switch test_opt
    case 1
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a 1D example for creating an EDF response surface
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Create some random samples from a generalized pareto
        % I'm not totally sure what the parameters mean
        N = 800;
        gp_k = -1/2;
        gp_sigma = 1;
        gp_theta = 0;
        x = sort(icdf('gp',rand(N,1),gp_k,gp_sigma,gp_theta));
        
        % Evaluate the EDF at the given points
        % I guess this could be other points instead, but whatever
        y = Fhat(x,x);
        
        % Plot the EDF from the randomly generated data
        Nplot = 500;
        xplot = pickpoints(gp_theta,gp_theta-gp_sigma/gp_k,Nplot);
        h_cdf_ex = figure;
        subplot(1,3,1)
        plot(xplot,cdf('gp',xplot,gp_k,gp_sigma,gp_theta),'r','linewidth',3);
        hold on
        plot(x,y,'linewidth',3)
        hold off
        title('Empirical CDF')
        legend('True','Empirical')
        
        % Choose an RBF to work with
        rbf = rbfM4;
        rbfdx = rbfM4dx;
        
        % Create the surrogate model
        ep = .3;
        mu = 1e-4;
        K_cdf = rbf(DistanceMatrix(x,x,ep));
        cdf_coef = (K_cdf+mu*eye(N))\y;
        cdf_eval = @(xeval) rbf(DistanceMatrix(xeval,x,ep))*cdf_coef;
        pdf_eval = @(xeval) rbfdx(DistanceMatrix(xeval,x,ep),DifferenceMatrix(xeval,x),ep)*cdf_coef;
        
        % Evaluate and plot the surrogate CDF
        cplot = cdf_eval(xplot);
        subplot(1,3,2)
        plot(xplot,cplot,'linewidth',3);
        title('Surrogate CDF')
        
        % Evaluate and plot the surrogate PDF
        pplot = pdf_eval(xplot);
        subplot(1,3,3)
%         plot(xplot,pdf('beta',xplot,beta_a,beta_b),'r','linewidth',3);
        plot(xplot,pdf('gp',xplot,gp_k,gp_sigma,gp_theta),'r','linewidth',3);
        hold on
        plot(xplot,pplot,'linewidth',3);
        title('Surrogate PDF')
        legend('True','Computed')
        hold off
    case 2
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a 2D example for creating an EDF response surface
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Create some random samples from a 2D standard normal
        N = 400;
        x = randn(N,2);
        
        % Evaluate the EDF at some points to create data for the model
        Ndata = 20;
        xdata = pick2Dpoints(min(x(:))*[1 1],max(x(:))*[1 1],Ndata*[1;1]);
        ydata = Fhat(xdata,x);
        
        % Plot the EDF from the randomly generated data
        h_cdf_ex = figure;
        subplot(1,3,1)
        surf(reshape(xdata(:,1),Ndata,Ndata),reshape(xdata(:,2),Ndata,Ndata),reshape(ydata,Ndata,Ndata))
        title('Empirical CDF')
        
        % Choose an RBF to work with
        rbf = rbfM6;
        rbfdxdy = rbfM6dxdy;
        
        % Create a surrogate model for the EDF
        ep = [1,1];
        mu = 4e-2;
        K_cdf = rbf(DistanceMatrix(xdata,xdata,ep));
        % cdf_coef = K_cdf\ydata;
        cdf_coef = (K_cdf+mu*eye(Ndata^2))\ydata;
        % cdf_coef = (K_cdf'*K_cdf+mu*eye(Ndata^2))\K_cdf'*ydata;
        cdf_eval = @(xeval) rbf(DistanceMatrix(xeval,xdata,ep))*cdf_coef;
        pdf_eval = @(xeval) max(rbfdxdy(DistanceMatrix(xeval,xdata,ep),DifferenceMatrix(xeval(:,1),xdata(:,1)),...
            DifferenceMatrix(xeval(:,2),xdata(:,2)),ep)*cdf_coef,0);
        
        % Evaluate and plot the surrogate CDF on a grid
        Nplot = 40;
        xplot = pick2Dpoints(min(x(:))*[1 1],max(x(:))*[1 1],Nplot*[1;1]);
        cplot = cdf_eval(xplot);
        subplot(1,3,2)
        surf(reshape(xplot(:,1),Nplot,Nplot),reshape(xplot(:,2),Nplot,Nplot),reshape(cplot,Nplot,Nplot))
        title('Surrogate CDF')
        
        % Evaluate and plot the surrogate PDF on a grid
        pplot = pdf_eval(xplot);
        subplot(1,3,3)
        surf(reshape(xplot(:,1),Nplot,Nplot),reshape(xplot(:,2),Nplot,Nplot),reshape(pplot,Nplot,Nplot))
        title('Surrogate PDF')
    case 3
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a 4D example for creating an EDF response surface
        %%% This example uses data distributed from the carsmall data set
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Load, clean and scale the data
        load carsmall
        xdirty = [Acceleration Displacement Horsepower Weight];
        xstr = {'Acceleration','Displacement','Horsepower','Weight'};
        ydirty = MPG;
        [x,y,shift,scale] = rescale_data(xdirty,ydirty);
        x_mean = mean(x);
        
        % Try to compute a 2D density over acceleration and horsepower
        xAD = x(:,1:2);
        NAD = size(xAD,1);
        N2d = 35;
        x2d = pick2Dpoints([-1 -1],[1 1],N2d*[1;1]);
        % Sorting may be useful but I haven't figured out why yet
        [c,i] = sort(sum(x2d - ones(N2d^2,1)*[-1,-1],2));
        x2d_sorted = x2d(i,:);
        [c,i] = sort(sum(xAD - ones(NAD,1)*[-1,-1],2));
        xAD_sorted = xAD(i,:);
        h_scatter = figure;
        scatter(xAD_sorted(:,1),xAD_sorted(:,2),exp(3*c))
        ecdf2d = zeros(N2d^2,1);
        for k=1:N2d^2
            ecdf2d(k) = sum(all(xAD<=repmat(x2d(k,:),NAD,1),2))/NAD;
        end
        h_ecdf = figure;
        surf(reshape(x2d(:,1),N2d,N2d),reshape(x2d(:,2),N2d,N2d),reshape(ecdf2d,N2d,N2d))
        
        rbf = rbfM6;
        rbfdxdy = rbfM6dxdy;
        
        ep = [3,3];
        mu = 1e-3;
        K_cdf = rbf(DistanceMatrix(x2d,x2d,ep));
        cdf2d_coef = (K_cdf+mu*eye(N2d^2))\ecdf2d;
        cdf2d_eval = @(xx) rbf(DistanceMatrix(xx,x2d,ep))*cdf2d_coef;
        pdf2d_eval = @(xx) max(rbfdxdy(DistanceMatrix(xx,x2d,ep),DifferenceMatrix(xx(:,1),x2d(:,1)),...
            DifferenceMatrix(xx(:,2),x2d(:,2)),ep)*cdf2d_coef,0);
        Neval = 50;
        x2d_eval = pick2Dpoints([-1 -1],[1 1],Neval*[1;1]);
        y_eval = cdf2d_eval(x2d_eval);
        surf(reshape(x2d_eval(:,1),Neval,Neval),reshape(x2d_eval(:,2),Neval,Neval),reshape(y_eval,Neval,Neval))
        y_eval = pdf2d_eval(x2d_eval);
        surf(reshape(x2d_eval(:,1),Neval,Neval),reshape(x2d_eval(:,2),Neval,Neval),reshape(y_eval,Neval,Neval))
    otherwise
        error('No such example exists')
end