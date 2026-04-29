clc; clear; close all;

%% =========================================================
%  MAGNUS EFFECT – 3-CURVE COMPARISON (MANUAL v_avg MODEL)
%
%  Curves:
%   (1) Measured
%   (2) Literature CL (manual input)
%   (3) Best-fit CL
%
%  Forces computed using manually provided v_avg:
%    F = 0.5 * rho * C * A * v_avg^2
% =========================================================

%% --- CONSTANTS -------------------------------------------
rho = 1.204;
CD  = 0.47;
R   = 0.0195;
DT  = 1e-4;

mass_foam = 0.0005;
mass_ping = 0.0028;

%% --- SELECT TRIAL ----------------------------------------
trials = {
    'f_CCW1.mat',      'Foam – CCW',         mass_foam;
    'f_CW1.mat',       'Foam – CW',          mass_foam;
    'f_straight1.mat', 'Foam – No Spin',     mass_foam;
    'p_CCW1.mat',      'Ping-Pong – CCW',    mass_ping;
    'p_CW1.mat',       'Ping-Pong – CW',     mass_ping;
    'p_straight1.mat', 'Ping-Pong – No Spin',mass_ping;
};

k = 6;  % <<< choose trial (1–6)

fname  = trials{k,1};
tlabel = trials{k,2};
mass   = trials{k,3};

%% --- MANUAL INPUTS ---------------------------------------
v_avg         = 3.59;   % <<< average speed [m/s]
CL_lit_manual = 1.41;   % <<< literature CL

%% --- LOAD DATA -------------------------------------------
d = load(fname);
r = d.results;

cx_mm   = r.cx_mm(:);
cy_mm   = r.cy_mm(:);
t_valid = r.t_valid(:);

vx0   =  r.vx_mms / 1000;
vy0   = -r.vy_mms / 1000;
omega =  r.omega_rad;

x_meas = cx_mm - cx_mm(1);
y_meas = -(cy_mm - cy_mm(1));

t_end      = t_valid(end) - t_valid(1);
A          = pi * R^2;
omega_phys = -omega;

%% --- FORCE DEBUG -----------------------------------------
FD     = 0.5 * rho * CD            * A * v_avg^2;
FM_lit = 0.5 * rho * CL_lit_manual * A * v_avg^2;

fprintf('\n===== FORCE DEBUG =====\n');
fprintf('v_avg     = %.3f m/s\n', v_avg);
fprintf('F_D       = %.4f N\n',   FD);
fprintf('F_M (lit) = %.4f N\n',   FM_lit);

%  (1) LITERATURE MODEL SIMULATION
[x_lit, y_lit] = simulate_constant_force( ...
    CL_lit_manual, vx0, vy0, omega_phys, FD, FM_lit, mass, DT, t_end);

x_lit = x_lit * 1000; y_lit = y_lit * 1000;

%  (2) BEST-FIT CL
obj = @(CL) trajectory_rmse(CL, vx0, vy0, omega_phys, ...
                             rho, CD, A, v_avg, mass, DT, t_end, ...
                             x_meas, y_meas);

% Coarse bracket
CL_candidates = linspace(0, 3, 60);
errs          = arrayfun(obj, CL_candidates);
[~, idx]      = min(errs);
CL_init       = CL_candidates(idx);

% Refine
options = optimset('TolX', 1e-6, 'TolFun', 1e-10, 'MaxIter', 5000);
CL_fit  = fminsearch(obj, CL_init, options);
rmse    = obj(CL_fit);

FM_fit = 0.5 * rho * CL_fit * A * v_avg^2;

fprintf('F_M (fit) = %.4f N\n', FM_fit);
fprintf('CL_fit    = %.4f\n',   CL_fit);
fprintf('RMSE      = %.3f mm\n', rmse);

[x_fit, y_fit] = simulate_constant_force( ...
    CL_fit, vx0, vy0, omega_phys, FD, FM_fit, mass, DT, t_end);

x_fit = x_fit * 1000;
y_fit = y_fit * 1000;

%  (3) PLOT
figure;
hold on; grid on;
ylim([-70,40])

plot(x_meas, y_meas, 'o-', 'DisplayName', 'Measured');

plot(x_lit, y_lit, '--', ...
    'DisplayName', sprintf('Literature C_L = %.3f', CL_lit_manual));

plot(x_fit, y_fit, ':', 'LineWidth', 2, ...
    'DisplayName', sprintf('Best-fit C_L = %.3f  (RMSE = %.2f mm)', ...
                           CL_fit, rmse));

legend('Location', 'best');
xlabel('x (mm)');
ylabel('y (mm)');
title(tlabel);

%  LOCAL FUNCTIONS
function rmse = trajectory_rmse(CL, vx0, vy0, omega_phys, ...
                                rho, CD, A, v_avg, mass, DT, t_end, ...
                                x_meas, y_meas)
%TRAJECTORY_RMSE  Arc-length-parameterised RMS error between
%  simulated and measured paths. Robust to point-count mismatch.

    FD = 0.5 * rho * CD  * A * v_avg^2;
    FM = 0.5 * rho * CL  * A * v_avg^2;

    [xs, ys] = simulate_constant_force(CL, vx0, vy0, omega_phys, ...
                                       FD, FM, mass, DT, t_end);
    xs = xs * 1000;
    ys = ys * 1000;

    % Arc-length parameterisation
    s_sim  = [0, cumsum(sqrt(diff(xs).^2  + diff(ys).^2))];
    s_meas = [0, cumsum(sqrt(diff(x_meas(:)').^2 + diff(y_meas(:)').^2))];

    if s_sim(end) < 1e-9 || s_meas(end) < 1e-9
        rmse = 1e6;
        return
    end

    s_sim  = s_sim  / s_sim(end);
    s_meas = s_meas / s_meas(end);

    xi = interp1(s_sim, xs, s_meas, 'linear', 'extrap');
    yi = interp1(s_sim, ys, s_meas, 'linear', 'extrap');

    rmse = sqrt(mean((xi - x_meas(:)').^2 + (yi - y_meas(:)').^2));
end

% ---------------------------------------------------------

function [xs, ys] = simulate_constant_force(CL, vx0, vy0, omega_phys, ...
                                            FD, FM, mass, DT, t_end)
%SIMULATE_CONSTANT_FORCE  Euler integration with constant force vectors.
%  Direction of drag and Magnus are fixed to the initial velocity
%  direction (constant-force assumption).

    vhat   = [vx0; vy0] / norm([vx0; vy0]);
    FD_vec = -FD * vhat;
    FM_vec =  -sign(omega_phys) * FM * [vhat(2); -vhat(1)];

    ax = (FD_vec(1) + FM_vec(1)) / mass;
    ay = (FD_vec(2) + FM_vec(2)) / mass;

    state = [0; 0; vx0; vy0];
    xs = 0;
    ys = 0;
    tt = 0;

    while tt < t_end
        state(1) = state(1) + state(3) * DT;
        state(2) = state(2) + state(4) * DT;
        state(3) = state(3) + ax * DT;
        state(4) = state(4) + ay * DT;
        xs(end+1) = state(1); %#ok<AGROW>
        ys(end+1) = state(2); %#ok<AGROW>
        tt = tt + DT;
    end
end