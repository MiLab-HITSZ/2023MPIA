clear;
clc;
close all;
rng default
rng(11)
runtimes = 30;
addpath(genpath(pwd));
delete(gcp('nocreate'));
parpool('local',runtimes);
%%
%%
data_seed = 12; % MPUAV1-6 are 12 , 7-12 are 121314
data_2();
data.alpha_trace = 60/360*(2*pi); % ?????
data.beta_trace = 45/360*(2*pi); % ??????
data.map_size=map_size;
data.P_crash = 3.42 * 10e-4; % ??????
data.S_hit=0.0188; % m^2 ??????
data.R_I = 0.3;  % ???????
data.R_vf = 0.27; % ????????
data.alpha=10^6; % J ????????
data.beta = 100; % J
data.S_c = 0.5 ; % ??????
data.g = 9.8 ; % m/s^2
data.IOT_pos=IOT_pos;
data.m = 1380 ; % g (DJI Phantom4)
data.rou_a = 1225 ; % g/m^3(???????)
data.miu = miu; % ?????????
data.sigma = sigma; % ?????????
data.v = 20; % 20m/s
S=[1 1];E=[45 45]; % ??????
data.S = S;
data.E = E;
data.minh=bulid_xyz;
data.maxh=141;
Bound = E(1)-S(1);
dim = Bound*2;
data.Bound = Bound;
data.map_step=map_step;
data.populations_risk=populations_risk;
data.road_risk=road_risk;
%% pre-cal
ystep = 3;
pbase = ystep+1;
for i = 1:2*ystep+1
    pi = i - pbase;
    can=[];
    for j = -ystep:1:ystep
        if acos([1,pi]*[1,j]'/sqrt(1+pi^2)/sqrt(1+(j)^2))<=data.alpha_trace
            can=[can j];
        end
    end
    canselect{i}=can;
end
data.canselect = canselect;
data.canselectp = pbase;
%%
tiledlayout(2,2);
for h = 30:30:120
    nexttile;
    Risk_map = zeros(map_size);
    Riskproperty_map = zeros(map_size);
    for i=1:map_size(1)
        for j =1:map_size(2)
            Risk_map(i,j)=Risk_map(i,j)+getC_Risk(getR_pf(getV(h,data),data),populations_risk(i,j),data);
            Risk_map(i,j)=Risk_map(i,j)+getC_Risk(data.R_vf,road_risk(i,j),data);
        end
    end
    colormap('jet')
    contourf(Risk_map)
    colorbar;
    title(['h=' num2str(h) 'm,' ' Risk of property=' num2str(getC_rpd(h,data))]);
end
%%
problemList={@MPUAV1,@MPUAV2,@MPUAV3,@MPUAV4,@MPUAV5,@MPUAV6};
maxiterList={100000,100000,100000,100000,100000,100000};
problemMean=zeros(numel(problemList)*2,7);
problemStd=zeros(numel(problemList)*2,7);
data.lb = [ones(1,dim/2-1).*-1 ones(1,dim/2+1).*0];
data.ub = [ones(1,dim/2-1).*ystep ones(1,dim/2+1).*1];
data.dim = dim;
temp.dec=0;
temp.obj=0;
RankANS_both = zeros(numel(problemList)*2,7,3);
RankANS_sum = zeros(numel(problemList),7,3);
for problemIndex= 1:numel(problemList)
    TT=runtimes;
    score=[];
    testfit = problemList{problemIndex};
    parfor testtimes = 1:TT
        close all;
        RANDSEED=testtimes;
        popnum=105;
        maxiter=maxiterList{problemIndex};
        %% NSGA2
        rng default;rng(RANDSEED);
        test_case={@OptAll,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population = MPSELECT(Global.result{2},100,2);
        [Population2,FrontNo,~] = NDSELECT(Global.result{2},min(numel(Global.result{2}),100));
        Population2=Population2(FrontNo==1);
        res_nsgadec=reshape([Population.dec],dim,[])';
        res_nsgaobj=reshape([Population.obj],size(Population(1).obj,2),[])';
        res_nsga2dec=reshape([Population2.dec],dim,[])';
        res_nsga2obj=reshape([Population2.obj],size(Population(1).obj,2),[])';
        %% MPNDS
        rng default;rng(RANDSEED);
        test_case={@OptMPNDS,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population= MPSELECT(Global.result{2},100,2);
        res_mpndsdec=reshape([Population.dec],dim,[])';
        res_mpndsobj=reshape([Population.obj],size(Population(1).obj,2),[])';
        %% MPNDS2
        rng default;rng(RANDSEED);
        test_case={@OptMPNDS2,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population= MPSELECT(Global.result{2},100,2);
        res_mpnds2dec=reshape([Population.dec],dim,[])';
        res_mpnds2obj=reshape([Population.obj],size(Population(1).obj,2),[])';
        %% MPNNIA
        rng default;rng(RANDSEED);
        test_case={@MPNNIA,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population= MPSELECT(Global.result{2},100,2);
        MPNNIAdec=reshape([Population.dec],dim,[])';
        MPNNIAobj=reshape([Population.obj],size(Population(1).obj,2),[])';
        %% MPHEIA
        rng default;rng(RANDSEED);
        test_case={@MPHEIA,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population= MPSELECT(Global.result{2},100,2);
        MPHEIAdec=reshape([Population.dec],dim,[])';
        MPHEIAobj=reshape([Population.obj],size(Population(1).obj,2),[])';
        %% MPAIMA
        rng default;rng(RANDSEED);
        test_case={@MPAIMA,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population= MPSELECT(Global.result{2},100,2);
        MPAIMAdec=reshape([Population.dec],dim,[])';
        MPAIMAobj=reshape([Population.obj],size(Population(1).obj,2),[])';
        %% MPIA
        rng default;rng(RANDSEED);
        test_case={@MPIA2,testfit,popnum,1,1,maxiter,dim};
        for i =1:numel(test_case)/7
            var={'-algorithm',test_case{i,1},'-problem',test_case{i,2},'-N',test_case{i,3},'-save',test_case{i,4},'-run',test_case{i,5}, ...,
                '-evaluation',test_case{i,6},'-D',test_case{i,7},'-data',data};
            Global = GLOBAL(var{:});
            Global.Start();
        end
        Population= MPSELECT(Global.result{2},min(numel(Global.result{2}),100),2);
        MPIAdec=reshape([Population.dec],dim,[])';
        MPIAobj=reshape([Population.obj],size(Population(1).obj,2),[])';
        allsol = [res_nsgaobj;res_mpndsobj;res_mpnds2obj;MPNNIAobj;MPHEIAobj;MPAIMAobj;MPIAobj];
        %allsol = P.Global.nonideal_VALUE;
        allsol(allsol(:,3)>1e5,:)=[];
        nsga_hv = bothHV(res_nsgaobj,allsol,2);
        mpnds_hv = bothHV(res_mpndsobj,allsol,2);
        mpnds2_hv = bothHV(res_mpnds2obj,allsol,2);
        MPNNIA_hv = bothHV(MPNNIAobj,allsol,2);
        MPHEIA_hv = bothHV(MPHEIAobj,allsol,2);
        MPAIMA_hv = bothHV(MPAIMAobj,allsol,2);
        MPIA_hv = bothHV(MPIAobj,allsol,2);
        score1(testtimes,:)=[nsga_hv(1) mpnds_hv(1) mpnds2_hv(1) MPNNIA_hv(1) MPHEIA_hv(1) MPAIMA_hv(1) MPIA_hv(1)];
        score2(testtimes,:)=[nsga_hv(2) mpnds_hv(2) mpnds2_hv(2) MPNNIA_hv(2) MPHEIA_hv(2) MPAIMA_hv(2) MPIA_hv(2)];
        nsga_hv = MEANHV(res_nsgaobj,allsol,2);
        mpnds_hv = MEANHV(res_mpndsobj,allsol,2);
        mpnds2_hv = MEANHV(res_mpnds2obj,allsol,2);
        MPNNIA_hv = MEANHV(MPNNIAobj,allsol,2);
        MPHEIA_hv = MEANHV(MPHEIAobj,allsol,2);
        MPAIMA_hv = MEANHV(MPAIMAobj,allsol,2);
        MPIA_hv = MEANHV(MPIAobj,allsol,2);
        score3(testtimes,:)=[nsga_hv mpnds_hv mpnds2_hv MPNNIA_hv MPHEIA_hv MPAIMA_hv MPIA_hv];
    end
    %% TEST1_ BOTH HV
    problemMean_both((problemIndex-1)*2+1,:)= mean(score1);
    problemMean_both((problemIndex-1)*2+2,:)= mean(score2)
    problemStd_both((problemIndex-1)*2+1,:)= std(score1);
    problemStd_both((problemIndex-1)*2+2,:)= std(score2);
    problemMean_sum(problemIndex,:)= mean(score3)
    problemStd_sum(problemIndex,:)=std(score3);
    for al = 1:6
        diff1 = ranksum(score1(:,al),score1(:,end))<0.1;
        if diff1
            if problemMean_both((problemIndex-1)*2+1,al)<problemMean_both((problemIndex-1)*2+1,end)
                RankANS_both((problemIndex-1)*2+1,al,1)=RankANS_both((problemIndex-1)*2+1,al,1)+1;
            else
                RankANS_both((problemIndex-1)*2+1,al,3)=RankANS_both((problemIndex-1)*2+1,al,3)+1;
            end
        else
            RankANS_both((problemIndex-1)*2+1,al,2)=RankANS_both((problemIndex-1)*2+1,al,2)+1;
        end
        diff2 = ranksum(score2(:,al),score2(:,end))<0.1;
        if diff2
            if problemMean_both((problemIndex-1)*2+2,al)<problemMean_both((problemIndex-1)*2+2,end)
                RankANS_both((problemIndex-1)*2+2,al,1)=RankANS_both((problemIndex-1)*2+2,al,1)+1;
            else
                RankANS_both((problemIndex-1)*2+2,al,3)=RankANS_both((problemIndex-1)*2+2,al,3)+1;
            end
        else
            RankANS_both((problemIndex-1)*2+2,al,2)=RankANS_both((problemIndex-1)*2+2,al,2)+1;
        end
    end
    figure()
    boxchart(score3)
    for al = 1:6
        diff3 = ranksum(score3(:,al),score3(:,end))<0.1;
        if diff3
            if problemMean_sum(problemIndex,al)<problemMean_sum(problemIndex,end)
                RankANS_sum(problemIndex,al,1)=RankANS_sum(problemIndex,al,1)+1;
            else
                RankANS_sum(problemIndex,al,3)=RankANS_sum(problemIndex,al,3)+1;
            end
        else
            RankANS_sum(problemIndex,al,2)=RankANS_sum(problemIndex,al,2)+1;
        end
    end
end

%%
