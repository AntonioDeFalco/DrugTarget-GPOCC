logtrasform = true;
scale = true;
norm_zscore = false;
pca_exc = false;
perc_pca = 80;
num_pca = 0;

%Training Set
if not(exist('T'))
    load('T.mat')
end

%All features
if not(exist('A'))
    load('A.mat')
end

%Validation Set
if not(exist('V'))
    load('V.mat')
end

features = [2:42,44:46,48,52:71];

if logtrasform
    features_log = [2,3,7:10,41,42,44,45,46,48,58];
else
    features_log = [];
end

x=read_features(T,features,features_log);
t=read_features(A,features,features_log);

%ONE-HOT ENCODING
x_categ = add_categorical(T);
x = [x,x_categ];
t_categ = add_categorical(A);
t = [t,t_categ];

%FREQUENCY ENCODING
x_categ = add_categorical2(T);
x = [x,x_categ];
t_categ = add_categorical2(A);
t = [t,t_categ];

n=size(x,1);
y = [ones(1,n)]';
[~,ia,~] = intersect(A(:,1), V(:,1));
n=size(t,1);
t_label = zeros(1,n)';
for i=ia
    t_label(i) = 1;
end

%Sequential forward selection (SFS)
%{
load('sel_features.mat');
%}
sel_features = sort(sel_features);
x = x(:,sel_features);
t = t(:,sel_features);


%{
load('/Users/anthony/Dropbox/tesi/gpml-matlab-master/doc/sel_features_sparse.mat');
sel_features = repInd;
x = x(:,sel_features);
t = t(:,sel_features);
%}

k = 30;
ka = 30;
%colmin = min(x);
%colmax = max(x);
%xx = rescale(x,'InputMin',colmin,'InputMax',colmax);

[idx, dist] = knnsearch(x, x, 'k', k);%,'Distance','jaccard');
sigma = log(dist(:,ka));
%sigma = dist(:,ka);
%sigma = dist(:,ka);
%sigma = rescale(sigma)+0.01;

dist=distance_pearson(x,x);
dist = sort(dist,2);
sigma = exp(dist(:,ka));


%% Scaled min max 
all = [x;t];

if scale
    colmin = min(all);
    colmax = max(all);
    all = rescale(all,'InputMin',colmin,'InputMax',colmax);
end

%% Normalize z-score

%
if norm_zscore
    all = normalize(all,2);  
end
%% PCA

if pca_exc
    [coeff,scoreTrain,~,~,explained,mu] = pca(all);

    if perc_pca
        sum_explained = 0;
        idx = 0;
        while sum_explained < perc_pca
            idx = idx + 1
            sum_explained = sum_explained + explained(idx);
        end
    else
        idx = num_pca;
    end
    all = scoreTrain(:,1:idx);
end

%%

x = all(1:102,:);
t = all(103:20402,:);

dist=distance_pearson(x,x);
dist = sort(dist,2);
sigma = exp(dist(:,ka));

modes={'mean','var','pred','ratio'};
titles={'mean \mu_*','neg. variance -\sigma^2_*','log. predictive probability p(y=1|X,y,x_*)','log. moment ratio \mu_*/\sigma_*'};

ins_pwr = x .^ 2;
var_pwr = sum(ins_pwr)/length(x) - (sum(x) / length(x)).^2;
svar = exp(2*log(var_pwr));
svar = mean(svar);

[K,Ks,Kss]=se_kernel(svar,sigma,x,t);

min_scores  = [];
max_scores  = [];
scores = [];
AUCs = [];
for i=1:4
    %compute scores
    score=GPR_OCC(K,Ks,Kss,modes{i});
    [X,Y,~,AUC] = perfcurve(t_label,score,1);
    figure(i)
    plot(X,Y)
    xlabel('False positive rate') 
    ylabel('True positive rate')
    title(sprintf('ROC %s',modes{i}))
    text(0.75,0.1,sprintf('AUC=%0.4f',AUC),'FontSize',14);
    
    min_score = min(score);
    max_score = max(score);
    min_scores = [min_scores,min_score];
    max_scores = [max_scores,max_score];
    scores = [scores,score];
    AUCs = [AUCs,AUC];
    
end

%mean = scores(:,1);
%var = scores(:,2);
%pred = scores(:,3);
%ratio = scores(:,4);

AUC_mean = AUCs(1);
AUC_var = AUCs(2);
AUC_pred = AUCs(3);
AUC_ratio = AUCs(4);

min_mean = min_scores(:,1);
min_var = min_scores(:,2);
min_pred = min_scores(:,3);
min_ratio = min_scores(:,4);

max_mean = max_scores(:,1);
max_var = max_scores(:,2);
max_pred = max_scores(:,3);
max_ratio = max_scores(:,4);

t_score = table(AUC_mean,AUC_var,AUC_pred,AUC_ratio,min_mean,min_var,min_pred,min_ratio,max_mean,max_var,max_pred,max_ratio);

writetable(t_score,'myData.xls');

function x=read_features(T,features,features_log)
    x = []
    
    for i = features
        if isnumeric(table2array(T(:,i)))
            v = table2array(T(:,i));   
        elseif iscellstr(table2array(T(:,i)))
            v = str2double(table2array(T(:,i)));
        end
        if ismember(i,features_log)
            v = log(v + 0.01);
        end    
        
    x=[x,v];
    end
   
end

function x=add_categorical(T,category_add)
    x = [];

    [genre, ~, index] = unique(T.EnzymeClassification);
    mat = logical(accumarray([(1:numel(index)).' index], 1));
    Hydrolases = mat(:,1);
    Lyases = mat(:,2);
    NotEnzyme = mat(:,3);
    Oxireductases = mat(:,4);
    Transferases = mat(:,5);
    Translocases = mat(:,6);
    EnzymeClassification = table(Hydrolases,Lyases,NotEnzyme,Oxireductases,Transferases,Translocases);

    [genre, ~, index] = unique(T.PESTRegion);
    mat = logical(accumarray([(1:numel(index)).' index], 1));
    Poor = mat(:,1);
    Potential = mat(:,2);
    PESTRegion = table(Poor,Potential);

    [genre, ~, index] = unique(T.SignalPeptide);
    SignalPeptide = index-1;
    SignalPeptide_t = table(index);
    
    
    [genre, ~, index] = unique(T.Essentiality);
    mat = logical(accumarray([(1:numel(index)).' index], 1));
    Essential = mat(:,1);
    NonEssential = mat(:,2);
    UK = mat(:,3);
    Essentiality = table(Essential,NonEssential,UK);

    
    [genre, ~, index] = unique(T.Localization);
    mat = logical(accumarray([(1:numel(index)).' index], 1));
    Chloroplast = mat(:,1);
    Cytoplasmic = mat(:,2);
    Extracellular = mat(:,3);
    Lysosomal = mat(:,4);
    Mitochondrial = mat(:,5);
    Nuclear = mat(:,6);
    PlasmaMembrane = mat(:,7);
    Localization = table(Chloroplast,Cytoplasmic,Extracellular,Lysosomal,Mitochondrial,Nuclear,PlasmaMembrane);
    
    [genre, ~, index] = unique(T.TransmembraneHelices);
    TransmembraneHelices_ = rescale(index);
    TransmembraneHelices = table(TransmembraneHelices_);
   
    categoricalFeatures = [Essentiality PESTRegion];
    
    for i=1:size(categoricalFeatures,2)
        x = [x,table2array(categoricalFeatures(:,i))];
    end
end

function x=add_categorical2(T)
    x = [];

    [genre, ~, index] = unique(T.EnzymeClassification);
    tbl = tabulate(T.EnzymeClassification);
    freq = [tbl{:,2}]';
    EnzymeClassification_ = freq(index(:));
    EnzymeClassification = table(EnzymeClassification_);

    [genre, ~, index] = unique(T.PESTRegion);
    tbl = tabulate(T.PESTRegion);
    freq = [tbl{:,2}]';
    PESTRegion_ = freq(index(:));
    PESTRegion = table(PESTRegion_);

    [genre, ~, index] = unique(T.SignalPeptide);
    tbl = tabulate(T.SignalPeptide);
    freq = [tbl{:,2}]';
    SignalPeptide = freq(index(:));
    SignalPeptide_t = table(SignalPeptide);
    
    [genre, ~, index] = unique(T.Essentiality);
    tbl = tabulate(T.Essentiality);
    freq = [tbl{:,2}]';
    Essentiality_ = freq(index(:));
    Essentiality = table(Essentiality_);
    
    [genre, ~, index] = unique(T.Localization);
    tbl = tabulate(T.Localization);
    freq = [tbl{:,2}]';
    Localization_ = freq(index(:));
    Localization = table(Localization_);
    
    categoricalFeatures = [EnzymeClassification SignalPeptide_t Localization];
   
    for i=1:size(categoricalFeatures,2)
        x = [x,table2array(categoricalFeatures(:,i))];
    end
end

%auxiliary functions for kernel computation. Note, however, that
%for efficiency reasons, faster implementations should be used
%(see the code distributed along the textbook
%"Gaussian Processes in Machine Learning", C. Rasmussen & C. Williams, 2006
function [K,Ks,Kss]=se_kernel(svar,ls,x,y)

    K   = svar*exp(-0.5*euclidean_distance2(x,x,ls));
    
    Ks = svar*exp(-0.5*euclidean_distance2(x,y,ls));  

    Kss  = svar*ones(size(y,1),1);
   
    
end
    
function distmat=euclidean_distance(x,y)
    distmat = zeros( size(x,1), size(y,1) );
    for i=1:size(x,1)
        for j=1:size(y,1)
            buff=(x(i,:)-y(j,:));   
            distmat(i,j)=buff*buff';
        end
    end
end

function distmat=euclidean_distance2(x,y,ls)
    distmat = zeros( size(x,1), size(y,1) );
    for i=1:size(x,1)
        for j=1:size(y,1)
            buff=(x(i,:)-y(j,:));
            buff=buff/ls(i);
            distmat(i,j)=buff*buff';
        end
    end
end

function distmat=euclidean_distance2_norm(x,y,ls) %normalize
    distmat = zeros( size(x,1), size(y,1) );
    for i=1:size(x,1)
        for j=1:size(y,1)            
            buff=0.5*(std(x(i,:)-y(j,:))^2) / (std(x(i,:))^2+std(y(j,:))^2);
            buff=buff/ls(i);
            distmat(i,j)=buff;
        end
    end
end

function distmat=euclidean_distance2_pearson(x,y,ls)
    distmat = zeros( size(x,1), size(y,1) );
    for i=1:size(x,1)
        for j=1:size(y,1)
            R = corrcoef(x(i,:),y(j,:));
            buff = (1-R(1,2))/ls(i);
            %buff = 1-R(1,2);
            %buff = pdist2(x(i,:),y(j,:),'correlation');
            distmat(i,j)= buff;
        end
    end
end

function distmat=euclidean_distance3(x,y,ls)
    distmat = zeros( size(x,1), size(y,1) );
    for i=1:size(x,1)
        for j=1:size(y,1)
            buff=(x(i,:)-y(j,:));
            buff=buff/ls(i);
            distmat(i,j)=buff*buff';
        end
    end
end
%D(p(x|i),p(x|j ))+

function distmat=distance_pearson(x,y)
    distmat = zeros( size(x,1), size(y,1) );
    for i=1:size(x,1)
        for j=1:size(y,1)
            R = corrcoef(x(i,:),y(j,:));
            buff = (1-R(1,2));
            %buff = R(1,2);
            %buff = R(1,2);
            %buff = 1-R(1,2);
            %buff = pdist2(x(i,:),y(j,:),'correlation');
            distmat(i,j)= buff;
        end
    end
end
