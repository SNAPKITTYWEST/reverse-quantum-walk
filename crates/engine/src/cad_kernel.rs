// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// First-principles 2D CAD constraint solver kernel.
// Replaces discrete F_p R1CS constraints (A·B - C = 0 mod p)
// with continuous spatial constraints over R^N.
// Newton-Raphson: X_new = X - J_pinv * C(X)
// ============================================================

#[derive(Debug, Clone, Copy)]
pub struct Point2D {
    pub x: f64,
    pub y: f64,
}

pub enum Constraint {
    /// (x1 - x2)^2 + (y1 - y2)^2 - d^2 = 0
    Distance { p1: usize, p2: usize, target: f64 },
    /// x - target_x = 0, y - target_y = 0
    Fixed { p: usize, target_x: f64, target_y: f64 },
    /// y1 - y2 = 0
    Horizontal { p1: usize, p2: usize },
    /// x1 - x2 = 0
    Vertical { p1: usize, p2: usize },
}

pub struct CadSystem {
    pub points: Vec<Point2D>,
    pub constraints: Vec<Constraint>,
}

impl CadSystem {
    pub fn new(points: Vec<Point2D>, constraints: Vec<Constraint>) -> Self {
        Self { points, constraints }
    }

    /// Evaluates residual error vector C(X)
    pub fn evaluate_residuals(&self) -> Vec<f64> {
        let mut residuals = Vec::new();
        for c in &self.constraints {
            match c {
                Constraint::Distance { p1, p2, target } => {
                    let dx = self.points[*p1].x - self.points[*p2].x;
                    let dy = self.points[*p1].y - self.points[*p2].y;
                    residuals.push(dx * dx + dy * dy - target * target);
                }
                Constraint::Fixed { p, target_x, target_y } => {
                    residuals.push(self.points[*p].x - target_x);
                    residuals.push(self.points[*p].y - target_y);
                }
                Constraint::Horizontal { p1, p2 } => {
                    residuals.push(self.points[*p1].y - self.points[*p2].y);
                }
                Constraint::Vertical { p1, p2 } => {
                    residuals.push(self.points[*p1].x - self.points[*p2].x);
                }
            }
        }
        residuals
    }

    /// Computes Jacobian dC_i/dX_j
    pub fn build_jacobian(&self) -> (Vec<f64>, usize, usize) {
        let num_vars = self.points.len() * 2;
        let residuals = self.evaluate_residuals();
        let num_constraints = residuals.len();
        let mut jacobian = vec![0.0; num_constraints * num_vars];

        let mut row = 0;
        for c in &self.constraints {
            match c {
                Constraint::Distance { p1, p2, .. } => {
                    let dx = self.points[*p1].x - self.points[*p2].x;
                    let dy = self.points[*p1].y - self.points[*p2].y;
                    jacobian[row * num_vars + (*p1 * 2)]     =  2.0 * dx;
                    jacobian[row * num_vars + (*p1 * 2 + 1)] =  2.0 * dy;
                    jacobian[row * num_vars + (*p2 * 2)]     = -2.0 * dx;
                    jacobian[row * num_vars + (*p2 * 2 + 1)] = -2.0 * dy;
                    row += 1;
                }
                Constraint::Fixed { p, .. } => {
                    jacobian[row * num_vars + (*p * 2)]     = 1.0; row += 1;
                    jacobian[row * num_vars + (*p * 2 + 1)] = 1.0; row += 1;
                }
                Constraint::Horizontal { p1, p2 } => {
                    jacobian[row * num_vars + (*p1 * 2 + 1)] =  1.0;
                    jacobian[row * num_vars + (*p2 * 2 + 1)] = -1.0;
                    row += 1;
                }
                Constraint::Vertical { p1, p2 } => {
                    jacobian[row * num_vars + (*p1 * 2)] =  1.0;
                    jacobian[row * num_vars + (*p2 * 2)] = -1.0;
                    row += 1;
                }
            }
        }
        (jacobian, num_constraints, num_vars)
    }

    /// Single Newton-Raphson step: X -= step_size * J^T * C(X)
    /// Returns total absolute residual.
    pub fn step_solve(&mut self, step_size: f64) -> f64 {
        let residuals = self.evaluate_residuals();
        let (jacobian, rows, cols) = self.build_jacobian();

        let mut delta = vec![0.0; cols];
        for j in 0..cols {
            let mut grad = 0.0;
            for i in 0..rows {
                grad += jacobian[i * cols + j] * residuals[i];
            }
            delta[j] = grad;
        }

        for p in 0..self.points.len() {
            self.points[p].x -= step_size * delta[p * 2];
            self.points[p].y -= step_size * delta[p * 2 + 1];
        }

        residuals.iter().map(|r| r.abs()).sum()
    }
}
