% DEMTOYGLASSORCA1 RCA-Glasso demo on simulated data.
%
% FORMAT
% DESC
%
% SEEALSO :
%
% COPYRIGHT : Alfredo A. Kalaitzis, 2011
%
% RCA

clear, clc
addpath(genpath('~/mlprojects/matlab/general/'))
addpath(genpath('~/mlprojects/rca/matlab/glasso/'))
importTool({'rca','ndlutil','gprege'})
asym = @(x) sum(sum(abs(x - x.'))); % Asymmetry test.

figure(1), clf, colormap('hot')
figure(2), clf, colormap('hot')
figure(3), clf, colormap('hot')
figure(4), clf, colormap('hot')
figure(5), clf, colormap('hot')

limit = 1e-5;
lambda = 5.^linspace(-8,3,30);
Sigma_hat = cell(length(lambda),1);
Lambda_hat = cell(length(lambda),1);
triuLambda_hat = cell(length(lambda),1);
B = cell(length(lambda),1);
TPs = zeros(length(lambda), 1);
FPs = zeros(length(lambda), 1);
FNs = zeros(length(lambda), 1);
TNs = zeros(length(lambda), 1);


%% Data generation.

d = 50; % Observed dimensions.
p = 3; % Low-rank
n = 100;
sigma2_n = 1e-2; % Noise variance.
s = RandStream('mcg16807','Seed', 1985); RandStream.setDefaultStream(s) % 1985
validLambda = false;
density = .01;
sp = ceil((d^2-d)/2 * density);
sel = randperm(d^2); % Random positions.
sel(mod(sel,d+1) == 1) = []; % Remove positions of the diagonal.
sel = sel(1:ceil( (d^2-d)/2 * density ));    % Enough random positions to satisfy the density.
Lambda = zeros(d);
Lambda(sel) = 1;
Lambda = triu(Lambda + Lambda',1) .* (randn(d)*sqrt(2) + 1);
while ~validLambda
    testLambda = Lambda + Lambda' + diag(abs(randn(d,1))).*4; % 4
    validLambda = all( eig(testLambda) > 0 );
end
Lambda = testLambda;
Sigma = pdinv(Lambda);
W = randn(d,p);
WWt = W*W';
Theta = WWt + Sigma + sigma2_n*eye(d);
Y = gaussSamp(Theta, n); % Sample from p(y).
figure(1), clf, colormap('hot')
subplot(131), imagesc(Lambda), title('sparse \Lambda'), colorbar
subplot(132), imagesc(Sigma), title('sparse-inverse \Sigma'), colorbar
subplot(133), imagesc(WWt), title('Low-rank WW'''), colorbar


Y = Y - repmat(mean(Y),n,1);
Cy = Y'*Y/n; % Sample covariance Y.
% totalvar = trace(Cy)/d;
%}


%% Standard Glasso on (un)confounded simulated data, with varying lambda.
%{
confounders{1} = WWt;   confounders{2} = zeros(size(WWt));
linestyle = {'-xb','--om'}; legends = {'GL','"Ideal" GL'};
AUCs = zeros(2,1); figure(2), clf, figure(4), clf
for c = 1:2
    s = RandStream('mcg16807','Seed', 666); RandStream.setDefaultStream(s) % 23, 1e5
    Y_ = gaussSamp(confounders{c} + Sigma + sigma2_n*eye(d), n);   Y_ = Y_ - repmat(mean(Y_),n,1);
    Cy_ = Y_'*Y_/n;
    A = boolean( triu(Lambda,1) ~= 0 );
    for i = 1:length(lambda)
        [Sigma_hat{i}, Lambda_hat{i}] = glasso(d, Cy_, 0, lambda(i)*ones(d), 0,0,0,1, 1e-4, 1e4, zeros(d), zeros(d));
        triuLambda_hat{i} = triu(Lambda_hat{i}, 1);
        figure(3), imagesc(Lambda_hat{i}), colormap(hot), colorbar,...
            title([ '(RCA)GLasso-recovered \Lambda with \lambda=', num2str(lambda(i)) ]);
        % Evaluation
        B{i} = boolean( triuLambda_hat{i} ~= 0 );
        TPs(i) = sum( A(:) & B{i}(:) );
        FPs(i) = sum( ~A(:) & B{i}(:) );
        FNs(i) = sum( A(:) & ~B{i}(:) );
        TNs(i) = sum( ~A(:) & ~B{i}(:) );
    end
    TPRs = TPs ./ (TPs + FNs);
    Precisions = TPs ./ (TPs + FPs);
    FPRs = FPs ./ (FPs + TNs);
    figure(2), hold on, plot(TPRs, Precisions, linestyle{c}), ylim([0 1]), xlabel('Recall'), ylabel('Precision')
    figure(4), hold on, plot(FPRs, TPRs, linestyle{c}), xlim([0 1]), xlabel('FPR'), ylabel('TPR')
    AUCs(c) = trapz(flipud(FPRs), flipud(TPRs)) / max(FPRs);
end
figure(2), legend(legends,1), title('Recall-Precision');
figure(4), legend([ legends{1} ' auc: ' num2str(AUCs(1)) ], [ legends{2} ' auc: ' num2str(AUCs(2)) ], 4), title('ROC');
%}


%% **USELESS** Standard GLasso on confounded simulated data, with varying lambda,
% *after* having explained away the true low-rank structure via RCA.
%{
s = RandStream('mcg16807','Seed', 666); RandStream.setDefaultStream(s) % 23, 1e5
Y_ = gaussSamp(Theta, n);   Y_ = Y_ - repmat(mean(Y_),n,1);
Cy_ = Y_'*Y_/n;
% Retrieve residual variance basis via RCA.
Theta_exp = WWt + sigma2_n*eye(d)*.95;
[S D] = eig(Cy_, Theta_exp);    [D perm] = sort(diag(D),'descend');
V_hat = Theta_exp * S(:,perm(D>1)) * sqrt(diag(D(D>1)-1));
VVt_hat = V_hat * V_hat' + sigma2_n*eye(d)*.05;
figure(3), imagesc(VVt_hat), colorbar
A = boolean(triu(full(Lambda),1) ~= 0);
for i = 1:length(lambda)
    [Sigma_hat{i}, Lambda_hat{i}] = glasso(d, VVt_hat, 0, lambda(i)*ones(d),0,0,0,0,1e-4,1e+4, zeros(d), zeros(d));
    triuLambda_hat{i} = triu(Lambda_hat{i}, 1);
    figure(3), imagesc(Lambda_hat{i}), colormap(hot), colorbar, ...
        title([ '(RCA)GLasso-recovered \Lambda with \lambda=', num2str(lambda(i)) ]);
    % Evaluation
    B{i} = boolean( triuLambda_hat{i} ~= 0 );
    TPs(i) = sum( A(:) & B{i}(:) );
    FPs(i) = sum( ~A(:) & B{i}(:) );
    FNs(i) = sum( A(:) & ~B{i}(:) );
    TNs(i) = sum( ~A(:) & ~B{i}(:) );
end
TPRs = TPs ./ (TPs + FNs);
Precisions = TPs ./ (TPs + FPs);
FPRs = FPs ./ (FPs + TNs);
figure(2), hold on, plot(TPRs, Precisions, ':rs'), ylim([0 1]), xlabel('Recall'), ylabel('Precision')
title('Recall-Precision');
figure(4), hold on, plot(FPRs, TPRs, ':rs'), xlim([0 1]), xlabel('FPR'), ylabel('TPR')
AUC = trapz(flipud(FPRs), flipud(TPRs)) / max(FPRs);
%}


%% Recovery of low-rank component WWt by explaining away the true
% sparse-inverse covariance Sigma.
%{
Theta_exp = Sigma + sigma2_n*eye(d);
[S D] = eig(Cy, Theta_exp);    [D perm] = sort(diag(D),'descend');
W_hat = Theta_exp * S(:,perm(D>1)) * sqrt(diag(D(D>1)-1));
WWt_hat = W_hat * W_hat';
figure(3), imagesc(WWt_hat), colorbar, title('WW'' by RCA');
figure(4), imagesc(WWt_hat - WWt), title('WW''-WWt_hat'), colorbar;
%}


%% Recovery of sparse-inverse and low-rank covariance via iterative
% application of GLASSO and RCA.

lambda = 10^-2.6;
for i = 1:length(lambda) % Try different magnitudes of lambda.
    
    % Initialise W with a PPCA low-rank estimate.
%     [S D] = eig(Cy);     [D perm] = sort(diag(D),'descend');
%     W_hat_old = S(:,perm(D>sigma2_n)) * sqrt(diag(D(D>sigma2_n)-sigma2_n));

%     W_hat_old = zeros(d,p);
    W_hat_old = W;  % True low-rank.
    
    WWt_hat_old = W_hat_old * W_hat_old';
    
%     Lambda_hat_old = zeros(d);
    Lambda_hat_old = Lambda;
    Sigma_hat_old = pdinv(Lambda);
    
    warmInit = true;
    figure(2), clf
    k = 1;
    lml_old = -Inf;
    converged = false;
    while ~converged
        fprintf('\nEM-RCA iteration: %d\n', k);
        
        % E step.
        WWt_plus_noise_inv = pdinv( WWt_hat_old + sigma2_n*eye(d) );
        V_f = pdinv(  WWt_plus_noise_inv  +  Lambda_hat_old ); % Posterior variance of f.
        E_f = (V_f * WWt_plus_noise_inv *  Y')'; % Posterior expectations E[f_n] as rows.
        Avg_E_fft = V_f  +  (E_f'*E_f)./n; % Second moment expectation.
        if rank(Avg_E_fft) < d
            warning([ 'rank(Avg_E_fft) = ', num2str(rank(Avg_E_fft)) ]); %#ok<*WNTAG>
        end

        % M step. Maximise p(f|Lambda) wrt Lambda, via GLASSO.
%         fprintf('\nEmpirical covariance for GLasso\n rank: %d cond: %f\n\n', rank(Avg_E_fft), cond(Avg_E_fft))
        warmLambda_hat = Lambda_hat_old;    warmSigma_hat = Sigma_hat_old;
        [Sigma_hat_new, Lambda_hat_new, iter, avgTol, hasError] = ...
            glasso ( d, Avg_E_fft, 0, lambda(i).*ones(d), ...   % numVars, empirical covariance, computePath, regul.matrix
            0, warmInit, 1, 1, ...  % approximate, warmInit, verbose, penalDiag
            1e-4, 1e2, ...          % tolThreshold, maxIter
            warmSigma_hat, warmLambda_hat);
%         if any(asym(Lambda_hat_new))
%             warning([ 'GLasso produced asymmetric Lambda_hat_new by ',...
%                 num2str(asym(Lambda_hat_new)), '. Lambda_hat_new not symmetrified.' ]);
%             Lambda_hat_new = (Lambda_hat_new + Lambda_hat_new') ./ 2; %   Symmetrify.
%         end
        Lambda_hat_new_inv = pdinv(Lambda_hat_new);
        
        % EM feedback.
        Theta_hat = WWt_hat_old + sigma2_n*eye(d) + Lambda_hat_new_inv;
        lml_new_em = -log(2*pi)*d*n/2 - log(det(Theta_hat))*n/2 - sum(sum((Y'*Y)'.*pdinv(Theta_hat)))/2;
        fprintf(['GLasso:\n GLasso iterations: %d\n Lambda_hat_new assymetry: %f\n ' ...
            'hasError: %d\n lambda: %f\n lml_new after EM: %f\n'], ...
            iter, asym(Lambda_hat_new), hasError, lambda(i), lml_new_em);
        figure(2), plot(k, lml_new_em,'.b'), hold on
        
        % Error check.
        if lml_new_em < lml_old
            warning([num2str(lml_new_em - lml_old) ' lml drop observed after this EM iteration!']);
            break
        end
        
        % RCA step: Maximisation of p(y) wrt to W, Cy partially explained by Lambda.
        Theta_explained = Lambda_hat_new_inv + sigma2_n*eye(d);
        [S D] = eig(Cy, Theta_explained);    [D perm] = sort(diag(D),'descend');
        W_hat_new = Theta_explained * S(:,perm(D>1)) * sqrt(diag(D(D>1)-1));
        WWt_hat_new = W_hat_new * W_hat_new';
        
        % RCA feedback
        Theta_hat = WWt_hat_new + Lambda_hat_new_inv + sigma2_n*eye(d);
        lml_new_rca = -log(2*pi)*d*n/2 - log(det(Theta_hat))*n/2 - sum(sum((Y'*Y)'.*pdinv(Theta_hat)))/2;
%         fprintf('RCA:\n rank(WWt_hat_new): %d\n lml_new after RCA: %f\n\n', ...
%             rank(WWt_hat_new), lml_new_rca);
        figure(2), plot(k+.5, lml_new_rca,'.r', k, lml_new_em,'.b'), hold on
        
        % Error check.
        if lml_new_rca < lml_new_em
            warning([num2str(lml_new_rca - lml_new_em) ' lml drop observed after RCA iteration!']);
            pause;
        end
        
        % Convergence / error check.
        if (lml_new_rca - lml_old) < limit
            if lml_old > lml_new_rca
                warning([num2str(lml_new_rca - lml_old) ' lml drop observed after this iteration!']);
                break
            else
                converged = true;
                fprintf('EM-RCA algorithm converged.\n\n')
            end
        end
        
        % Prepare for new iteration.
        lml_old = lml_new_rca;
        warmInit = true;
        Lambda_hat_old = Lambda_hat_new;    WWt_hat_old = WWt_hat_new;
        k = k + 1;
        
        % Plot results of this iteration.
%         figure(5), clf, colormap('hot')
%         subplot(131), imagesc(Lambda_hat_new), colorbar
%             title([ 'GLasso/RCA-recovered \Lambda with \lambda=', num2str(lambda(i)) ]);
%         subplot(132), imagesc(Lambda_hat_new_inv), colorbar, title('\Sigma_{hat}'), colorbar
%         subplot(133), imagesc(WWt_hat_new), colorbar, title('RCA-recovered WW'''), colorbar
    end
    
    % Plot results.
    figure(5), clf, colormap('hot')
    subplot(131), imagesc(Lambda_hat_new), colorbar
        title([ 'GLasso/RCA-recovered \Lambda with \lambda=', num2str(lambda(i)) ]);
    subplot(132), imagesc(Lambda_hat_new_inv), colorbar, title('\Sigma_{hat}'), colorbar
    WWt_hat_new(WWt_hat_new > max(WWt(:))) = max(WWt(:));   WWt_hat_new(WWt_hat_new < min(WWt(:))) = min(WWt(:));
    subplot(133), imagesc(WWt_hat_new), colorbar, title('RCA-recovered WW'''), colorbar
    
    % Performance stats.
    A = boolean(triu(Lambda,1) ~= 0);
    triuLambda_hat{i} = triu(Lambda_hat_new, 1);
    B{i} = boolean( triuLambda_hat{i} ~= 0 );
    TPs(i) = sum( A(:) & B{i}(:) );
    FPs(i) = sum( ~A(:) & B{i}(:) );
    FNs(i) = sum( A(:) & ~B{i}(:) );
    TNs(i) = sum( ~A(:) & ~B{i}(:) );
end
TPRs = TPs ./ (TPs + FNs);
Precisions = TPs ./ (TPs + FPs);
FPRs = FPs ./ (FPs + TNs);
AUC = trapz(flipud(FPRs), flipud(TPRs)) / max(FPRs);
figure(3), hold on, plot(TPRs, Precisions, '-rs'), xlim([0 1]), ylim([0 1]), xlabel('Recall'), ylabel('Precision'), title('Recall-Precision')
figure(4), hold on, plot(FPRs, TPRs, '-rs'), xlim([0 1]), ylim([0 1]), xlabel('FPR'), ylabel('TPR')
legend([ 'RCA-GLasso auc: ' num2str(AUC) ], 4), title('ROC');
%}

