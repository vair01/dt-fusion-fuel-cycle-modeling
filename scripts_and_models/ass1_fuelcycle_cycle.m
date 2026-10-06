clear; close all; clc; 
set(0,'defaultlinelinewidth',2)
set(0,'defaultaxesfontsize',16)

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

fprintf('Minimum number of pumps: %.0f\n', n_pumps)
fprintf('---------------------------------------------------------\n')


% Mol of H until saturation is reached for one pump
Mol_H = Cs*as*Apanel; 

% "Mol flow rate"
MolFR_H = (N_D_div*2)/Nav; % mol/s
tau_cp = n_pumps*Mol_H/MolFR_H; % s

fprintf('Computed residence time for cryopumps: %.2f s\n', tau_cp)
fprintf('---------------------------------------------------------\n')

% Volume cryopumps concentration verification
Vtot = 10; % m^3
Vmax = 0.03*Vtot;
n = Mol_H;
P= 1e5;
R= 8.314;
T= 300; % K
V_max_ev=n*R*T/P;

c_max = V_max_ev/Vtot*100;

fprintf('Volume concentration of hydrogen in the cryopumps: %.2f%% -->', c_max );
if c_max < 3
    fprintf(' SAFE, 3%% Safety margin respected\n')
else fprintf(' NOT SAFE, 3%% Safety margin NOT respected\n')
end
fprintf('---------------------------------------------------------\n')


%% 2) Plasma
t_period = t_pulse + t_dwell; 
pulse_width = t_pulse/t_period;

%% 3) Storage and delivery
I_inventory = 1400; % g, initial guess (to be updated with iterations)

T_Tinj = N_T_div*conv; 

outputPath = 'sim_assignment_drive/Storage and delivery system/Isds';
ouput_pumps_path = 'sim_assignment_drive/I_CP';

TBRPath = 'sim_assignment_drive/Blanket1/Constant2';

open_system("sim_assignment_drive.slx");
inc=0.01; % Reduced increment for TBRr
min_inv = -1;
fprintf ('Minimum values and correspondig time of SDS inventory for different TBRr and startup inventory:\n')
fprintf('---> to stop the iteration it must be > 0\n')
fprintf ('     (for each startup inventory, iteration will stop at the minimum TBRr needed to get the inventory target in 2 years)\n')
fprintf('---------------------------------------------------------\n')

% Iteration for optimized I startup
while min_inv < 0 && I_inventory <= 5000 % Added an upper limit for I_inventory to prevent infinite loops
    TBR=1.04; % initial guess (to be updated with iterations)
    ii=1;
    ll=1;
    TBR_vec_current_inventory = []; % Store TBR values for the current I_inventory
    output_data_vec_current_inventory = {}; % Store output data for the current I_inventory
    min_inv_vec_current_inventory = [];
    t_min_inv_current_inventory = [];

    fprintf('Try number %.0f - Startup inventory set to %.0f g\n', ll, I_inventory)
    fprintf('    TBRr | Minimum SDS inventory Value | Time [s] | Time [d] \n');
    fprintf('   ---------------------------------------------------------\n')
       

        % Iteration for optimized TBRr 
        while TBR <= 1.09 % Iterate TBRr from 1.04 to 1.09
            set_param(TBRPath,'Value',num2str(TBR));
        
            % Ensure the simulation runs up to t_d
            out=sim("sim_assignment_drive.slx", 'StopTime', num2str(t_d)); 
        
            output_data_vec_current_inventory{ii} = out.yout{1}.Values.Data;
            output_data_end = output_data_vec_current_inventory{ii}(end);
        
            min_inv_vec_current_inventory (ii) = min(out.yout{1}.Values.Data);
            
            [min_val, ind_min_inv] = min(out.yout{1}.Values.Data);
            t_min_inv_current_inventory(ii) = out.tout(ind_min_inv);
            
            fprintf('    %.2f |          %.2f g            | %.0f s | %.2f days\n', ...
                TBR, min_inv_vec_current_inventory(ii), ...
                t_min_inv_current_inventory(ii), ...
                t_min_inv_current_inventory(ii)/(3600*24) )
            
            TBR_vec_current_inventory(ii) = TBR;
            ii=ii+1;
            TBR=TBR+inc; % Increment TBR for the next iteration
        
        end

    % Check if any of the runs for the current I_inventory resulted in min_inv > 0
    if any(min_inv_vec_current_inventory > 0)
        min_inv = max(min_inv_vec_current_inventory); % Set min_inv to a positive value to exit the outer loop
        TBR_vec = TBR_vec_current_inventory;
        output_data_vec = output_data_vec_current_inventory;
    else
        I_inventory = I_inventory + 50;
        ll=ll+1;
    end
    fprintf('-------------------------------------------------------------\n')
end

% Grafico
target_inventory = 2*I_inventory;
output_pumps = out.yout{2}.Values.Data(end);

time = out.yout{1}.Values.Time;


figure
for jj=1:length(TBR_vec)
    displayNameStr = sprintf('TBR_r = %.2f', TBR_vec(jj)); 
    plot(time, output_data_vec{jj}.*1e-3, 'DisplayName', displayNameStr);
    hold on
end
hold on
etichetta_target = sprintf ('Inventory target = %.2f kg', target_inventory*1e-3);

% Use 'HandleVisibility', 'off' for yline to prevent it from appearing in the legend
yline(target_inventory*1e-3, 'r', etichetta_target, 'LabelHorizontalAlignment','center', 'FontSize',14, 'HandleVisibility','off');

testo_td = "2 years";

xticks(t_d); 
xticklabels(testo_td);

title (sprintf('SDS inventory evolution over time with different TBRr, Startup inventory = %.2f g', I_inventory))
legend('show')
xlabel('Time (s)');
ylabel('SDS Tritium Inventory (kg)');
xlim([0,t_d])
grid on;

% Adjust y-axis limits to ensure the target line label is visible
% Find the min and max y values from your plotted data
all_y_data = cell2mat(output_data_vec);
min_y = min(all_y_data(:)) * 1e-3;
max_y = max(all_y_data(:)) * 1e-3;

% Calculate new y-axis limits, ensuring enough space for the target line and label
% Add a small margin above and below the data, and explicitly include the target line
y_lower_bound = min(min_y, target_inventory*1e-3) * 0.9; 
y_upper_bound = max(max_y, target_inventory*1e-3) * 1.1; 

ylim([y_lower_bound, y_upper_bound]);