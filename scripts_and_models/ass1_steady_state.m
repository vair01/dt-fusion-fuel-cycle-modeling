clear; close all; clc; 
set(0,'defaultlinelinewidth',2)
set(0,'defaultaxesfontsize',14)

%% ALL remaining data
% Residence times
tau_bb = 3600; % s
tau_tes = 24*3600;
tau_hx = 3600; 
tau_p = 6*3600; 
tau_sds = 3600; 

% Additional design parameters
t_pulse = 15*60; 
t_dwell = 2*60; 
eta_tes = 0.9; 
eps = 1e-4;
p_div = 1; %Pa
TBE = 0.01; 
f_dir = 0.3; 
t_d = 2*365*24*3600; % Doubling time (s)

Pfus = 500e6; % W
Efus = 17.6; % MeV
Efus_J = Efus*1.602e-13; % J

% For simulink
lambda = 1.83e-9; % 1/s
Nav = 6.022e23; % #part/mol
conv = 3/Nav;

%% 1) Cryopumps
% Data
S_D = 50; % m^3/s
Cs = 25; % molH/kg
as = 0.6; % kg/m^2
Apanel = 3; % m^2

Tconv = 273.15; % K
kB = 1.380e-23; % J/K

% Evaluation of T and He pumping speed
S_T = S_D*sqrt(2/3); 
S_He = S_D*sqrt(2/4); 

% Evaluation of particles fluxes to divertor
N_He_div = Pfus/Efus_J; 
N_T_div = N_He_div*(1/TBE-1); 
N_D_div = N_T_div; 

% Evaluation of throughput Q = V*p_div and V*p_div = N*k_B*T
Q_He = N_He_div*kB*Tconv; 
Q_T = N_T_div*kB*Tconv; 
Q_D = N_D_div*kB*Tconv; 

Q_tot = Q_He + Q_T + Q_D; 
x_He = 0.0055; 
x_D = 0.49725; 
x_T = 0.49725; 
n_pumps_partial = Q_tot/(x_T*S_T + x_D*S_D + x_He*S_He);
n_pumps = ceil(n_pumps_partial);


% Mol of H until saturation is reached for one pump
Mol_H = Cs*as*Apanel; 
% "Mol flow rate"
MolFR_H = (N_D_div*2)/Nav; % mol/s
tau_cp = n_pumps*Mol_H/MolFR_H; % s

% Volume cryopumps concentration verification
Vtot = 10; % m^3
Vmax = 0.03*Vtot;
n = Mol_H;
P= 1e5;
R= 8.314;
T= 300; % K
V_max_ev=n*R*T/P;
c_max = V_max_ev/Vtot*100;

%% 2) Plasma
t_period = t_pulse + t_dwell; 
pulse_width = t_pulse/t_period;

%% Optimal inizial values to study steady-state
I_inventory = 1450; % I_startup (g)
TBR = 1.09; % -
t_sim = 5 * tau_tes; % 432000 s

modelName = "sim_assignment_drive";
TBRPath = "sim_assignment_drive/Blanket1/Constant2";

load_system("sim_assignment_drive.slx");
set_param(TBRPath, 'Value', num2str(TBR));

fprintf('Start steady-state simulation for t = %.0f s (5 days)...\n', t_sim);
out = sim(modelName, 'StopTime', num2str(t_sim));
fprintf('Simulation completed with success!\n');

%% 3. Data extraction
time = out.tout;

I_SDS = out.yout{1}.Values.Data; % Storage and Delivery
I_CP  = out.yout{2}.Values.Data; % Cryopumps
I_P   = out.yout{3}.Values.Data; % Processing
I_BB  = out.yout{4}.Values.Data; % Breeding Blancket
I_TES = out.yout{5}.Values.Data; % Tritium Extraction System
I_HX  = out.yout{6}.Values.Data; % Heat Exchanger

%% 4. Plots
% Single plot with all the tritium inventory in each component 
figure(1);
plot(time, I_HX,  'LineWidth', 2); 
hold on;
plot(time, I_BB,  'LineWidth', 2);
plot(time, I_TES, 'LineWidth', 2);
plot(time, I_P,   'LineWidth', 2);
plot(time, I_CP,  'LineWidth', 2);
plot(time, I_SDS, 'LineWidth', 2);

grid on; 
box on;
xlabel('Time (s)');
ylabel('Tritium inventory of each component until steady-state (g)');
title('Tritium inventories at steady-state');
xlim([0, t_sim]);
ylim([0, 1600]);

legend({'Heat exchanger', 'Blanket', 'Tritium extraction system', ...
        'Tritium processing', 'Vacuum pumps', 'Storage and delivery'}, ...
        'Location', 'north', 'Orientation', 'horizontal');

% Subplots with the tritium inventory in each component
figure(2)
subplot(3, 2, 1)
plot(time, I_HX, 'Color', [0.85 0.75 0.1]);
title('Heat exchanger'); 
ylabel('Tritium inventory (g)'); 
grid on; 
xlim([0, t_sim]);

subplot(3, 2, 2)
plot(time, I_P, 'Color', [0.2 0.7 0.2]);
title('Tritium processing'); 
ylabel('Tritium inventory (g)'); 
grid on; 
xlim([0, t_sim]);

subplot(3, 2, 3)
plot(time, I_BB, 'Color', [0 0.5 0.8]);
title('Blanket'); 
ylabel('Tritium inventory (g)'); 
grid on; 
xlim([0, t_sim]);

subplot(3, 2, 4)
plot(time, I_CP, 'Color', [0.6 0.2 0.8]);
title('Vacuum pumps'); 
ylabel('Tritium inventory (g)'); 
grid on; 
xlim([0, t_sim]);

subplot(3, 2, 5)
plot(time, I_TES, 'Color', [0.9 0.4 0.1]);
title('Tritium extraction system'); 
ylabel('Tritium inventory (g)'); 
xlabel('Time (s)'); 
grid on; 
xlim([0, t_sim]);

subplot(3, 2, 6)
plot(time, I_SDS, 'Color', [0.2 0.8 0.9]);
title('Storage and delivery'); 
ylabel('Tritium inventory (g)'); 
xlabel('Time (s)'); 
grid on; 
xlim([0, t_sim]);