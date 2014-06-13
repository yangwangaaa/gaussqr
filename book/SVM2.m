% This tests the support vector machine content that appears in the book
% After running this, h will contain the figure handle of the plot that is
% created.  If two plots are created, h1 and h2 are the figure handles.

% To allow for the low-rank expansion parameter to be set
global GAUSSQR_PARAMETERS

% Initial example for support-vector machines
if exist('rng','builtin')
    rng(0);
else
    rand('state',0);
    randn('state',0);
end

% Define our Gaussian RBF
rbf = @(e,r) exp(-(e*r).^2);

% Choose a shape parameter or range of ep to test
ep = .1;
epvec = logspace(-2,2,31);

% Choose a box constraint or range of bc to test
box_constraint = .6;
bcvec = logspace(-2,2,20);

% Choose the number of cross-validations to compute
cv_fold = 3;

% Use the low rank matrix multiplication strategy
low_rank = 0;
GAUSSQR_PARAMETERS.DEFAULT_REGRESSION_FUNC = .05;

% Whether or not the user wants the results plotted
%   0 - study of alpha values in low rank fit
%   1 - graphic display of predictions
%   2 - tests range of epsilon values
%   3 - tests range of box constraint values
%   4 - 3D plot of both epsilon and box constraint range
%   5 - evaluate cross-validation error for range of ep values
plot_results = 3;

% Define our normal distributions
grnmean = [1,0];
redmean = [0,1];
grncov = eye(2);
redcov = eye(2);

% How many points of each model do we want to classify and learn from
grn_test_N = 10;
red_test_N = 10;
grn_train_N = 100;
red_train_N = 100;

% How much fudge factor do we want in our training set
grn_buffer = .2;
red_buffer = .2;

% Generate some manufactured data and attempt to classify it
% The data will be generated by normal distributions with different means
% Half of the data will come from [1,0] and half from [0,1]
grnpop = mvnrnd(grnmean,grncov,grn_test_N);
redpop = mvnrnd(redmean,redcov,red_test_N);

% Generate a training set from which to learn the classifier
grnpts = zeros(grn_train_N,2);
redpts = zeros(red_train_N,2);
for i = 1:grn_train_N
    grnpts(i,:) = mvnrnd(grnpop(ceil(rand*grn_test_N),:),grncov*grn_buffer);
end
for i = 1:red_train_N
    redpts(i,:) = mvnrnd(redpop(ceil(rand*red_test_N),:),redcov*red_buffer);
end

% Create a vector of data and associated classifications
% Green label 1, red label -1
train_data = [grnpts;redpts];
train_class = ones(grn_train_N+red_train_N,1);
train_class(grn_train_N+1:grn_train_N+red_train_N) = -1;
N_train = length(train_class);
test_data = [grnpop;redpop];
test_class = ones(grn_test_N+red_test_N,1);
test_class(grn_test_N+1:grn_test_N+red_test_N) = -1;
N_test = length(test_class);

% Plot the results, if requested
switch(plot_results)
    case 0
        K = exp(-ep^2*DistanceMatrix(train_data,train_data).^2);
        alphavec = logspace(0,8,30);
        errvec = zeros(size(alphavec));
        k = 1;
        for alpha=alphavec
            GQR = gqr_solveprep(1,train_data,ep,alpha);
            Phi1 = gqr_phi(GQR,train_data);
            Kpp = Phi1*diag(GQR.eig(GQR.Marr))*Phi1';
            errvec(k) = errcompute(Kpp,K);
            k = k + 1;
        end
        loglog(alphavec,errvec)
        xlabel('GQR alpha')
        ylabel('errcompute(low rank,K)')
        title(sprintf('ep=%4.2g,M=%d',ep,length(GQR.Marr)))
    case 1
        % Fit the SVM using the necessary parameters
        SVM = gqr_fitsvm(train_data,train_class,ep,box_constraint,low_rank);

        % Evaluate the classifications of the test data
        % Separate the correct classifications from the incorrect classifications
        predicted_class = SVM.eval(test_data);
        correct = predicted_class==test_class;
        incorrect = predicted_class~=test_class;
        
        % Plot the results
        d = 0.02;
        [CD1,CD2] = meshgrid(min(train_data(:,1)):d:max(train_data(:,1)),...
            min(train_data(:,2)):d:max(train_data(:,2)));
        contour_data = [CD1(:),CD2(:)];
        contour_class = SVM.eval(contour_data);

        h = figure;
        hold on
        plot(grnpop(:,1),grnpop(:,2),'g+','markersize',12)
        plot(redpop(:,1),redpop(:,2),'rx','markersize',12)
        plot(test_data(correct,1),test_data(correct,2),'ob','markersize',12)
        plot(test_data(incorrect,1),test_data(incorrect,2),'oc','markersize',12,'linewidth',2)
        plot(grnmean(1),grnmean(2),'gh','linewidth',3)
        plot(redmean(1),redmean(2),'rh','linewidth',3)
        plot(grnpts(:,1),grnpts(:,2),'g.')
        plot(redpts(:,1),redpts(:,2),'r.')
        plot(train_data(SVM.sv_index,1),train_data(SVM.sv_index,2),'ok','markersize',3)
        contour(CD1,CD2,reshape(contour_class,size(CD1)),[0 0],'k');
        hold off
    case 2
        % Test a bunch of ep values with a fixed box_constraint to see what the
        % results look like
        errvec = zeros(size(epvec));
        marvec = zeros(size(epvec));
        svmvec = zeros(size(epvec));
        k = 1;
        for ep=epvec
            SVM = gqr_fitsvm(train_data,train_class,ep,box_constraint,low_rank);
            errvec(k) = sum(test_class ~= SVM.eval(test_data));
            marvec(k) = SVM.margin;
            svmvec(k) = sum(SVM.sv_index);
            fprintf('%d\t%d\t%5.2f\t%d\n',k,svmvec(k),ep,SVM.exitflag)
            k = k + 1;
        end
        
        h1 = figure;
        semilogx(epvec,errvec,'linewidth',2)
        xlabel('\epsilon')
        ylabel('missed classifications')
        
        h2 = figure;
        [AX,H1,H2] = plotyy(epvec,svmvec,epvec,marvec,'semilogx','loglog');
        xlabel('\epsilon')
        ylabel(AX(1),'support vectors')
        ylabel(AX(2),'margin')
        set(AX(1),'ycolor','k')
        set(AX(2),'ycolor','k')
        set(AX(1),'ylim',[50,200])
        set(AX(2),'ylim',[.1,1])
        set(AX(2),'xlim',[.01,100])
        set(AX(2),'xticklabel',{})
        set(AX(1),'ytick',[50,100,150,200])
        set(AX(2),'ytick',[.1,1])
        set(H1,'color','k')
        set(H2,'color','k')
        set(H1,'linestyle','--')
        set(H1,'linewidth',2)
        set(H2,'linewidth',2)
        title(sprintf('C=%g',box_constraint))
        legend('# SV','Margin','location','east')
    case 3
        % Test a bunch of box_constraint values with a fixed ep to see what the
        % results look like
        errvec = zeros(size(bcvec));
        marvec = zeros(size(bcvec));
        k = 1;
        for bc=bcvec
            SVM = gqr_fitsvm(train_data,train_class,ep,bc,low_rank);
            errvec(k) = sum(test_class ~= SVM.eval(test_data));
            marvec(k) = SVM.margin;
            fprintf('%d\t%d\t%4.2f\t%d\n',k,sum(SVM.sv_index),bc,SVM.exitflag)
            k = k + 1;
        end
        
        h = figure;
        [AX,H1,H2] = plotyy(bcvec,errvec,bcvec,marvec,'semilogx','loglog');
        xlabel('box constraint')
        ylabel(AX(1),'missed classifications')
        ylabel(AX(2),'margin')
        set(AX(2),'ycolor','r')
        set(AX(1),'ytick',[0,5,10,15,20])
        set(AX(2),'ytick',[.01,.1,1])
        set(H2,'color','r')
        set(H1,'linewidth',2)
        set(H2,'linewidth',2)
        title(sprintf('\\epsilon=%4.2g',ep))
    case 4
        % Loops over selected epsilon and box constraint values
        % and records the incorrect classifications for each
        errmat = zeros(length(epvec),length(bcvec));
        marmat = zeros(length(epvec),length(bcvec));
        kep = 1;
        h_waitbar = waitbar(0,'Initiating');pause(.1)
        for ep=epvec
            kbc = 1;
            for bc=bcvec
                SVM = gqr_fitsvm(train_data,train_class,ep,bc,low_rank);
                errmat(kep,kbc) = sum(test_class ~= SVM.eval(test_data));
                marmat(kep,kbc) = SVM.margin;
                kbc = kbc + 1;
            end
            kep = kep + 1;
            progress = floor(100*kep/length(epvec))/100;
            waitbar(progress,h_waitbar,'Computing')
        end
        waitbar(1,h_waitbar,'Plotting')
        [E,B] = meshgrid(epvec,bcvec);
        h = surf(E,B,errmat');
        set(h,'edgecolor','none')
        set(gca,'xscale','log')
        set(gca,'yscale','log')
        close(h_waitbar)
    case 5
        % Define the objective function and try to find the minimum ep
        % value on an interval
        errvec = zeros(size(epvec));
        k = 1;
        for ep=epvec
            errvec(k) = gqr_svmcv(cv_fold,train_data,train_class,ep,box_constraint,low_rank);
            k = k + 1
        end
        semilogx(epvec,errvec)
%         ep_opt = fminbnd(@(ep)gqr_svmcv(cv_fold,train_data,train_class,ep,box_constraint),1,10);
end