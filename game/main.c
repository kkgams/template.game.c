#include "app.h"
#include "vendor/sokol_gfx.h"
#include "triangle-sapp.glsl.h"

// Supplied by the platform entry point.
sg_swapchain get_sokol_swapchain(void);

static sg_pipeline pipeline;
static sg_bindings bindings;

void init(void) {
    const float vertices[] = {
         0.0f,  0.5f, 0.5f, 1.0f, 0.0f, 0.0f, 1.0f,
         0.5f, -0.5f, 0.5f, 0.0f, 1.0f, 0.0f, 1.0f,
        -0.5f, -0.5f, 0.5f, 0.0f, 0.0f, 1.0f, 1.0f,
    };
    bindings.vertex_buffers[0] = sg_make_buffer(&(sg_buffer_desc){
        .data = SG_RANGE(vertices),
    });
    pipeline = sg_make_pipeline(&(sg_pipeline_desc){
        .shader = sg_make_shader(triangle_shader_desc(sg_query_backend())),
        .layout.attrs = {
            [ATTR_triangle_position].format = SG_VERTEXFORMAT_FLOAT3,
            [ATTR_triangle_color0].format = SG_VERTEXFORMAT_FLOAT4,
        },
    });
}

void frame(void) {
    sg_begin_pass(&(sg_pass){
        .action.colors[0] = {
            .load_action = SG_LOADACTION_CLEAR,
            .clear_value = {0.0f, 0.0f, 0.0f, 1.0f},
        },
        .swapchain = get_sokol_swapchain(),
    });
    sg_apply_pipeline(pipeline);
    sg_apply_bindings(&bindings);
    sg_draw(0, 3, 1);
    sg_end_pass();
    sg_commit();
}

void cleanup(void) {
    sg_shutdown();
}
