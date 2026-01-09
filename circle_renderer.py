#!/usr/bin/env python3
"""
GPU-accelerated circle rendering using PyOpenCL.
Renders circles from disk stabbing queries with hardware acceleration.
"""

import numpy as np
import pyopencl as cl
import pyopencl.array
from dataclasses import dataclass
from typing import List, Tuple, Optional

# OpenCL kernel for circle rendering
CIRCLE_KERNEL = """
__kernel void render_circles(
    __global const float4* circles,  // (cx, cy, r, color_index)
    __global uchar4* framebuffer,     // RGBA output
    const int width,
    const int height,
    const int n_circles,
    const float x_min,
    const float y_min,
    const float x_scale,
    const float y_scale
) {
    int x = get_global_id(0);
    int y = get_global_id(1);

    if (x >= width || y >= height) return;

    // Map pixel to world coordinates
    float wx = x_min + x * x_scale;
    float wy = y_min + y * y_scale;

    // Check all circles (back to front)
    uchar4 color = (uchar4)(0, 0, 0, 0);  // Transparent background

    for (int i = 0; i < n_circles; i++) {
        float4 c = circles[i];
        float dx = wx - c.x;
        float dy = wy - c.y;
        float dist_sq = dx * dx + dy * dy;

        if (dist_sq <= c.z * c.z) {
            // Inside circle - compute color from index
            int idx = (int)c.w;
            uchar r = (idx * 73) % 256;
            uchar g = (idx * 151) % 256;
            uchar b = (idx * 227) % 256;
            color = (uchar4)(r, g, b, 255);
        }
    }

    framebuffer[y * width + x] = color;
}
"""

# Kernel for highlighting query results
HIGHLIGHT_KERNEL = """
__kernel void highlight_circles(
    __global const float4* circles,
    __global const int* highlighted,  // indices of circles to highlight
    __global uchar4* framebuffer,
    const int width,
    const int height,
    const int n_highlighted,
    const float x_min,
    const float y_min,
    const float x_scale,
    const float y_scale
) {
    int x = get_global_id(0);
    int y = get_global_id(1);

    if (x >= width || y >= height) return;

    float wx = x_min + x * x_scale;
    float wy = y_min + y * y_scale;

    for (int i = 0; i < n_highlighted; i++) {
        int circle_idx = highlighted[i];
        float4 c = circles[circle_idx];
        float dx = wx - c.x;
        float dy = wy - c.y;
        float dist_sq = dx * dx + dy * dy;

        if (dist_sq <= c.z * c.z) {
            // Highlight with bright color
            framebuffer[y * width + x] = (uchar4)(255, 255, 0, 255);
            return;
        }
    }
}
"""

# Kernel for drawing query point
POINT_KERNEL = """
__kernel void draw_point(
    __global uchar4* framebuffer,
    const int width,
    const int height,
    const float qx,
    const float qy,
    const float x_min,
    const float y_min,
    const float x_scale,
    const float y_scale
) {
    int x = get_global_id(0);
    int y = get_global_id(1);

    if (x >= width || y >= height) return;

    float wx = x_min + x * x_scale;
    float wy = y_min + y * y_scale;

    float dx = wx - qx;
    float dy = wy - qy;
    float dist = sqrt(dx * dx + dy * dy);

    // Draw crosshair
    if (dist < 0.3 || (fabs(dx) < 0.05 && fabs(dy) < 1.0) || (fabs(dy) < 0.05 && fabs(dx) < 1.0)) {
        framebuffer[y * width + x] = (uchar4)(255, 0, 0, 255);
    }
}
"""


@dataclass
class Circle:
    cx: float
    cy: float
    r: float


class CircleRenderer:
    """GPU-accelerated circle renderer using OpenCL"""

    def __init__(self, width: int = 1920, height: int = 1080):
        self.width = width
        self.height = height

        # Initialize OpenCL
        self.ctx = cl.create_some_context(interactive=False)
        self.queue = cl.CommandQueue(self.ctx)

        # Compile kernels
        self.program = cl.Program(self.ctx, CIRCLE_KERNEL + HIGHLIGHT_KERNEL + POINT_KERNEL).build()

        # Allocate framebuffer
        self.framebuffer = cl.array.zeros(
            self.queue,
            (height, width, 4),
            dtype=np.uint8
        )

    def render(
        self,
        circles: List[Circle],
        bounds: Optional[Tuple[float, float, float, float]] = None,
        query_point: Optional[Tuple[float, float]] = None,
        highlighted: Optional[List[int]] = None,
    ) -> np.ndarray:
        """
        Render circles to framebuffer.

        Args:
            circles: List of circles to render
            bounds: (x_min, y_min, x_max, y_max) or None for auto
            query_point: (x, y) point to highlight or None
            highlighted: List of circle indices to highlight or None

        Returns:
            RGBA numpy array of shape (height, width, 4)
        """
        if not circles:
            return np.zeros((self.height, self.width, 4), dtype=np.uint8)

        # Compute bounds
        if bounds is None:
            x_min = min(c.cx - c.r for c in circles)
            x_max = max(c.cx + c.r for c in circles)
            y_min = min(c.cy - c.r for c in circles)
            y_max = max(c.cy + c.r for c in circles)

            # Add margin
            x_range = x_max - x_min
            y_range = y_max - y_min
            margin = 0.1
            x_min -= margin * x_range
            x_max += margin * x_range
            y_min -= margin * y_range
            y_max += margin * y_range
        else:
            x_min, y_min, x_max, y_max = bounds

        # Compute scaling
        x_scale = (x_max - x_min) / self.width
        y_scale = (y_max - y_min) / self.height

        # Prepare circle data (cx, cy, r, index)
        circle_data = np.array([
            [c.cx, c.cy, c.r, float(i)]
            for i, c in enumerate(circles)
        ], dtype=np.float32)

        # Upload to GPU
        circles_buf = cl.Buffer(
            self.ctx,
            cl.mem_flags.READ_ONLY | cl.mem_flags.COPY_HOST_PTR,
            hostbuf=circle_data
        )

        # Clear framebuffer
        self.framebuffer.fill(0)

        # Render circles
        self.program.render_circles(
            self.queue,
            (self.width, self.height),
            None,
            circles_buf,
            self.framebuffer.data,
            np.int32(self.width),
            np.int32(self.height),
            np.int32(len(circles)),
            np.float32(x_min),
            np.float32(y_min),
            np.float32(x_scale),
            np.float32(y_scale),
        )

        # Highlight specific circles if requested
        if highlighted:
            highlighted_buf = cl.Buffer(
                self.ctx,
                cl.mem_flags.READ_ONLY | cl.mem_flags.COPY_HOST_PTR,
                hostbuf=np.array(highlighted, dtype=np.int32)
            )

            self.program.highlight_circles(
                self.queue,
                (self.width, self.height),
                None,
                circles_buf,
                highlighted_buf,
                self.framebuffer.data,
                np.int32(self.width),
                np.int32(self.height),
                np.int32(len(highlighted)),
                np.float32(x_min),
                np.float32(y_min),
                np.float32(x_scale),
                np.float32(y_scale),
            )

        # Draw query point if requested
        if query_point:
            qx, qy = query_point
            self.program.draw_point(
                self.queue,
                (self.width, self.height),
                None,
                self.framebuffer.data,
                np.int32(self.width),
                np.int32(self.height),
                np.float32(qx),
                np.float32(qy),
                np.float32(x_min),
                np.float32(y_min),
                np.float32(x_scale),
                np.float32(y_scale),
            )

        # Download result
        result = self.framebuffer.get()
        return result


def demo():
    """Demo the circle renderer"""
    print("GPU Circle Renderer Demo")
    print("=" * 70)

    # Create some test circles
    circles = [
        Circle(0.0, 0.0, 5.0),
        Circle(3.0, 0.0, 3.0),
        Circle(-3.0, 2.0, 2.5),
        Circle(1.0, 4.0, 2.0),
        Circle(-2.0, -3.0, 3.5),
    ]

    # Create renderer
    renderer = CircleRenderer(width=1920, height=1080)

    # Render without query
    print("Rendering circles...")
    img1 = renderer.render(circles)
    print(f"  Output shape: {img1.shape}")
    print(f"  Non-zero pixels: {np.count_nonzero(img1)}")

    # Render with query point
    print("\nRendering with query point...")
    img2 = renderer.render(
        circles,
        query_point=(1.0, 0.5),
        highlighted=[0, 1]  # Highlight circles 0 and 1
    )
    print(f"  Output shape: {img2.shape}")
    print(f"  Non-zero pixels: {np.count_nonzero(img2)}")

    # Try saving with PIL if available
    try:
        from PIL import Image
        Image.fromarray(img1, 'RGBA').save('circles_basic.png')
        Image.fromarray(img2, 'RGBA').save('circles_query.png')
        print("\nSaved images: circles_basic.png, circles_query.png")
    except ImportError:
        print("\nPIL not available, skipping image save")

    print("\n" + "=" * 70)
    print("Demo complete!")


if __name__ == "__main__":
    demo()
