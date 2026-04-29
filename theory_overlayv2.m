clc; clear; close all;

%% =========================================================
%  MAGNUS EFFECT – THEORETICAL vs MEASURED TRAJECTORY
%
%  MODIFIED VERSION:
%   • Manual input of drag + Magnus forces (constant)
%   • Analyze ONE trial at a time
% =========================================================

%% --- USER INPUT -------------------------------------------
DT   = 1e-4;        % RK4 time step [s]
DPI  = 300;         % output resolution

% Ball masses [kg]
mass_foam = 0.0005;
mass_ping = 0.0028;

%% --- SELECT TRIAL -----------------------------------------
trials = {
    'f_CCW1.mat',      'Foam – CCW',         mass_foam;
    'f_CW1.mat',       'Foam – CW',          mass_foam;
    'f_straight1.mat', 'Foam – No Spin',     mass_foam;
    'p_CCW1.mat',      'Ping-Pong – CCW',    mass_ping;
    'p_CW1.mat',       'Ping-Pong – CW',     mass_ping;
    'p_straight1.mat', 'Ping-Pong – No Spin',mass_ping;
};

k = 6;   % <<< CHANGE THIS (1–6) to pick trial

fname  = trials{k, 1};
tlabel = trials{k, 2};
mass   = trials{k, 3};

%% --- LOAD DATA --------------------------------------------
d       = load(fname);
r       = d.results;

cx_mm   = r.cx_mm(:);
cy_mm   = r.cy_mm(:);
t_valid = r.t_valid(:);

vx0     =  r.vx_mms / 1000;   % m/s
vy0     = -r.vy_mms / 1000;   % flip image y → physics y

% Normalize measured trajectory
x_meas = cx_mm - cx_mm(1);
y_meas = -(cy_mm - cy_mm(1));

%% --- MANUAL FORCE INPUT -----------------------------------
% Set force [N]
FM = 0.002333713002;   % Magnus force
FD = 0.01059960054;   % Drag force

% Initial velocity direction
v0_vec = [vx0; vy0];
vhat   = v0_vec / norm(v0_vec);

% Drag (opposite velocity)
FD_vec = -FD * vhat;

% Magnus (perpendicular to velocity)
FM_vec = FM * [vhat(2); -vhat(1)];

FMx = FM_vec(1);
FMy = FM_vec(2);
FDx = FD_vec(1);
FDy = FD_vec(2);

%% --- RK4 INTEGRATION --------------------------------------
t_end = t_valid(end) - t_valid(1);

state = [0; 0; vx0; vy0];   % [x; y; vx; vy]
xs = 0;
ys = 0;
tt = 0;

while tt < t_end
    k1 = eom(state, mass, FMx, FMy, FDx, FDy);
    k2 = eom(state + 0.5*DT*k1, mass, FMx, FMy, FDx, FDy);
    k3 = eom(state + 0.5*DT*k2, mass, FMx, FMy, FDx, FDy);
    k4 = eom(state + DT*k3,     mass, FMx, FMy, FDx, FDy);

    state = state + (DT/6) * (k1 + 2*k2 + 2*k3 + k4);
    tt = tt + DT;

    xs(end+1) = state(1); %#ok<AGROW>
    ys(end+1) = state(2); %#ok<AGROW>
end

x_theo = xs * 1000;   % m → mm
y_theo = ys * 1000;

%% --- PLOTTING ---------------------------------------------
C_MEAS = [0      0.4470 0.7410];
C_THEO = [0.8500 0.3250 0.0980];
LW = 1.8;  MS = 5;

fig = figure('Units','centimeters','Position',[2 2 18 13]);
ax  = styled_axes(fig);
hold(ax, 'on');

% Measured
hM = plot(ax, x_meas, y_meas, '-o', ...
    'Color', C_MEAS, 'LineWidth', LW, 'MarkerSize', MS, ...
    'MarkerFaceColor', C_MEAS, 'MarkerEdgeColor', C_MEAS, ...
    'DisplayName', 'Measured');

plot_end_markers(ax, x_meas, y_meas, C_MEAS, MS);

% Theoretical
hT = plot(ax, x_theo, y_theo, '--', ...
    'Color', C_THEO, 'LineWidth', LW, ...
    'DisplayName', 'Theoretical');

plot_end_markers(ax, x_theo, y_theo, C_THEO, MS);

% Legend markers
hS = plot(ax, nan, nan, 'o', 'MarkerSize', MS+3, ...
    'LineStyle', 'none', 'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', [0.4 0.4 0.4], ...
    'DisplayName', 'Start');

hE = plot(ax, nan, nan, 's', 'MarkerSize', MS+3, ...
    'LineStyle', 'none', 'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', [0.4 0.4 0.4], ...
    'DisplayName', 'End');

legend(ax, [hM, hT, hS, hE], 'Location', 'best');

xlabel(ax, 'Horizontal displacement (mm)');
ylabel(ax, 'Vertical displacement (mm)');
title(ax, sprintf('%s | Manual Forces', tlabel), ...
    'FontWeight', 'bold', 'FontSize', 12);

% Annotation
info_str = {
    sprintf('F_M = %.2f mN', FM*1000), ...
    sprintf('F_D = %.2f mN', FD*1000), ...
    sprintf('m   = %.1f g',  mass*1000)
};

annotation(fig, 'textbox', [0.14 0.70 0.01 0.01], ...
    'String', info_str, 'FontSize', 9, ...
    'BackgroundColor', 'w', ...
    'EdgeColor', [0.6 0.6 0.6], ...
    'FitBoxToText', 'on');

% Save
safe_label = strrep(strrep(tlabel, ' ', '_'), char(8211), '-');
out_name   = sprintf('theory_overlay_%s_manual.png', safe_label);

exportgraphics(fig, out_name, 'Resolution', DPI);
fprintf('Saved: %s\n', out_name);

%% =========================================================
%  LOCAL FUNCTIONS
% =========================================================

function ds = eom(state, mass, FMx, FMy, FDx, FDy)
%EOM  Constant-force model (manual input)

    vx = state(3);
    vy = state(4);

    ax = (FMx + FDx) / mass;
    ay = (FMy + FDy) / mass;

    ds = [vx; vy; ax; ay];
end

% ---------------------------------------------------------

function ax = styled_axes(fig)
    ax = axes(fig);
    box(ax, 'on');
    grid(ax, 'on');
    ax.GridColor      = [0.85 0.85 0.85];
    ax.TickDir        = 'in';
    ax.XMinorTick     = 'on';
    ax.YMinorTick     = 'on';
    ax.FontSize       = 11;
end

% ---------------------------------------------------------

function plot_end_markers(ax, x, y, color, ms)
    plot(ax, x(1), y(1), 'o', 'MarkerSize', ms+3, ...
        'Color', color, 'MarkerFaceColor', 'w', ...
        'LineWidth', 1.5, 'HandleVisibility', 'off');

    plot(ax, x(end), y(end), 's', 'MarkerSize', ms+3, ...
        'Color', color, 'MarkerFaceColor', 'w', ...
        'LineWidth', 1.5, 'HandleVisibility', 'off');
end