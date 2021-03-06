/*
 * Copyright (c) 2006-2007 Erin Catto http://www.box2d.org
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 * claim that you wrote the original software. If you use this software
 * in a product, an acknowledgment in the product documentation would be
 * appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 * misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */
module tests.raycast;

import core.stdc.math;

import std.string;
import std.typecons;

import deimos.glfw.glfw3;

import dbox;

import framework.debug_draw;
import framework.test;

// This test demonstrates how to use the world ray-cast feature.
// NOTE: we are intentionally filtering one of the polygons, therefore
// the ray will always miss one type of polygon.

// This callback finds the closest hit. Polygon 0 is filtered.
class RayCastClosestCallback : b2RayCastCallback
{
    override float32 ReportFixture(b2Fixture* fixture, b2Vec2 point, b2Vec2 normal, float32 fraction)
    {
        b2Body* body_   = fixture.GetBody();
        void* userData = body_.GetUserData();

        if (userData)
        {
            int32 index = *cast(int32*)userData;

            if (index == 0)
            {
                // By returning -1, we instruct the calling code to ignore this fixture and
                // continue the ray-cast to the next fixture.
                return -1.0f;
            }
        }

        m_hit    = true;
        m_point  = point;
        m_normal = normal;

        // By returning the current fraction, we instruct the calling code to clip the ray and
        // continue the ray-cast to the next fixture. WARNING: do not assume that fixtures
        // are reported in order. However, by clipping, we can always get the closest fixture.
        return fraction;
    }

    bool m_hit;
    b2Vec2 m_point;
    b2Vec2 m_normal;
}


// This callback finds any hit. Polygon 0 is filtered. For this type of query we are usually
// just checking for obstruction, so the actual fixture and hit point are irrelevant.
class RayCastAnyCallback : b2RayCastCallback
{
    override float32 ReportFixture(b2Fixture* fixture, b2Vec2 point, b2Vec2 normal, float32 fraction)
    {
        b2Body* body_   = fixture.GetBody();
        void* userData = body_.GetUserData();

        if (userData)
        {
            int32 index = *cast(int32*)userData;

            if (index == 0)
            {
                // By returning -1, we instruct the calling code to ignore this fixture
                // and continue the ray-cast to the next fixture.
                return -1.0f;
            }
        }

        m_hit    = true;
        m_point  = point;
        m_normal = normal;

        // At this point we have a hit, so we know the ray is obstructed.
        // By returning 0, we instruct the calling code to terminate the ray-cast.
        return 0.0f;
    }

    bool m_hit;
    b2Vec2 m_point;
    b2Vec2 m_normal;
}

// This ray cast collects multiple hits along the ray. Polygon 0 is filtered.
// The fixtures are not necessary reported in order, so we might not capture
// the closest fixture.
class RayCastMultipleCallback : b2RayCastCallback
{
    enum
    {
        e_maxCount = 3
    }

    override float32 ReportFixture(b2Fixture* fixture, b2Vec2 point, b2Vec2 normal, float32 fraction)
    {
        b2Body* body_   = fixture.GetBody();
        void* userData = body_.GetUserData();

        if (userData)
        {
            int32 index = *cast(int32*)userData;

            if (index == 0)
            {
                // By returning -1, we instruct the calling code to ignore this fixture
                // and continue the ray-cast to the next fixture.
                return -1.0f;
            }
        }

        assert(m_count < e_maxCount);

        m_points[m_count]  = point;
        m_normals[m_count] = normal;
        ++m_count;

        if (m_count == e_maxCount)
        {
            // At this point the buffer is full.
            // By returning 0, we instruct the calling code to terminate the ray-cast.
            return 0.0f;
        }

        // By returning 1, we instruct the caller to continue without clipping the ray.
        return 1.0f;
    }

    b2Vec2 m_points[e_maxCount];
    b2Vec2 m_normals[e_maxCount];
    int32  m_count;
}

class RayCast : Test
{
    enum
    {
        e_maxBodies = 256
    }

    alias Mode = int;
    enum : Mode
    {
        e_closest,
        e_any,
        e_multiple
    }

    this()
    {
        m_edge = new typeof(m_edge);
        m_circle = new typeof(m_circle);

        foreach (ref poly; m_polygons)
            poly = new typeof(poly);

        // Ground body_
        {
            b2BodyDef bd;
            b2Body* ground = m_world.CreateBody(&bd);

            auto shape = new b2EdgeShape();
            shape.Set(b2Vec2(-40.0f, 0.0f), b2Vec2(40.0f, 0.0f));
            ground.CreateFixture(shape, 0.0f);
        }

        {
            b2Vec2 vertices[3];
            vertices[0].Set(-0.5f, 0.0f);
            vertices[1].Set(0.5f, 0.0f);
            vertices[2].Set(0.0f, 1.5f);
            m_polygons[0].Set(vertices);
        }

        {
            b2Vec2 vertices[3];
            vertices[0].Set(-0.1f, 0.0f);
            vertices[1].Set(0.1f, 0.0f);
            vertices[2].Set(0.0f, 1.5f);
            m_polygons[1].Set(vertices);
        }

        {
            float32 w = 1.0f;
            float32 b = w / (2.0f + b2Sqrt(2.0f));
            float32 s = b2Sqrt(2.0f) * b;

            b2Vec2 vertices[8];
            vertices[0].Set(0.5f * s, 0.0f);
            vertices[1].Set(0.5f * w, b);
            vertices[2].Set(0.5f * w, b + s);
            vertices[3].Set(0.5f * s, w);
            vertices[4].Set(-0.5f * s, w);
            vertices[5].Set(-0.5f * w, b + s);
            vertices[6].Set(-0.5f * w, b);
            vertices[7].Set(-0.5f * s, 0.0f);

            m_polygons[2].Set(vertices);
        }

        {
            m_polygons[3].SetAsBox(0.5f, 0.5f);
        }

        {
            m_circle.m_radius = 0.5f;
        }

        {
            m_edge.Set(b2Vec2(-1.0f, 0.0f), b2Vec2(1.0f, 0.0f));
        }

        m_bodyIndex = 0;
        m_bodies[] = null;

        m_angle = 0.0f;

        m_mode = e_closest;
    }

    void Create(int32 index)
    {
        if (m_bodies[m_bodyIndex] != null)
        {
            m_world.DestroyBody(m_bodies[m_bodyIndex]);
            m_bodies[m_bodyIndex] = null;
        }

        b2BodyDef bd;

        float32 x = RandomFloat(-10.0f, 10.0f);
        float32 y = RandomFloat(0.0f, 20.0f);
        bd.position.Set(x, y);
        bd.angle = RandomFloat(-b2_pi, b2_pi);

        m_userData[m_bodyIndex] = index;
        bd.userData = m_userData.ptr + m_bodyIndex;

        if (index == 4)
        {
            bd.angularDamping = 0.02f;
        }

        m_bodies[m_bodyIndex] = m_world.CreateBody(&bd);

        if (index < 4)
        {
            b2FixtureDef fd;
            fd.shape    = m_polygons[index];
            fd.friction = 0.3f;
            m_bodies[m_bodyIndex].CreateFixture(&fd);
        }
        else if (index < 5)
        {
            b2FixtureDef fd;
            fd.shape    = m_circle;
            fd.friction = 0.3f;

            m_bodies[m_bodyIndex].CreateFixture(&fd);
        }
        else
        {
            b2FixtureDef fd;
            fd.shape    = m_edge;
            fd.friction = 0.3f;

            m_bodies[m_bodyIndex].CreateFixture(&fd);
        }

        m_bodyIndex = (m_bodyIndex + 1) % e_maxBodies;
    }

    void DestroyBody()
    {
        for (int32 i = 0; i < e_maxBodies; ++i)
        {
            if (m_bodies[i] != null)
            {
                m_world.DestroyBody(m_bodies[i]);
                m_bodies[i] = null;
                return;
            }
        }
    }

    override void Keyboard(int key)
    {
        switch (key)
        {
            case GLFW_KEY_1:
            case GLFW_KEY_2:
            case GLFW_KEY_3:
            case GLFW_KEY_4:
            case GLFW_KEY_5:
            case GLFW_KEY_6:
                Create(key - GLFW_KEY_1);
                break;

            case GLFW_KEY_D:
                DestroyBody();
                break;

            case GLFW_KEY_M:

                if (m_mode == e_closest)
                {
                    m_mode = e_any;
                }
                else if (m_mode == e_any)
                {
                    m_mode = e_multiple;
                }
                else if (m_mode == e_multiple)
                {
                    m_mode = e_closest;
                }

                break;

            default:
                break;
        }
    }

    override void Step(Settings* settings)
    {
        super.Step(settings);

        bool advanceRay = settings.pause == 0 || settings.singleStep;

        g_debugDraw.DrawString(5, m_textLine, "Press 1-6 to drop stuff, m to change the mode");
        m_textLine += DRAW_STRING_NEW_LINE;

        switch (m_mode)
        {
            case e_closest:
                g_debugDraw.DrawString(5, m_textLine, "Ray-cast mode: closest - find closest fixture along the ray");
                break;

            case e_any:
                g_debugDraw.DrawString(5, m_textLine, "Ray-cast mode: any - check for obstruction");
                break;

            case e_multiple:
                g_debugDraw.DrawString(5, m_textLine, "Ray-cast mode: multiple - gather multiple fixtures");
                break;

            default:
        }

        m_textLine += DRAW_STRING_NEW_LINE;

        float32 L = 11.0f;
        b2Vec2 point1 = b2Vec2(0.0f, 10.0f);
        b2Vec2 d = b2Vec2(L * cosf(m_angle), L * sinf(m_angle));
        b2Vec2 point2 = point1 + d;

        if (m_mode == e_closest)
        {
            RayCastClosestCallback callback = new RayCastClosestCallback();
            m_world.RayCast(callback, point1, point2);

            if (callback.m_hit)
            {
                g_debugDraw.DrawPoint(callback.m_point, 5.0f, b2Color(0.4f, 0.9f, 0.4f));
                g_debugDraw.DrawSegment(point1, callback.m_point, b2Color(0.8f, 0.8f, 0.8f));
                b2Vec2 head = callback.m_point + 0.5f * callback.m_normal;
                g_debugDraw.DrawSegment(callback.m_point, head, b2Color(0.9f, 0.9f, 0.4f));
            }
            else
            {
                g_debugDraw.DrawSegment(point1, point2, b2Color(0.8f, 0.8f, 0.8f));
            }
        }
        else if (m_mode == e_any)
        {
            RayCastAnyCallback callback = new RayCastAnyCallback();
            m_world.RayCast(callback, point1, point2);

            if (callback.m_hit)
            {
                g_debugDraw.DrawPoint(callback.m_point, 5.0f, b2Color(0.4f, 0.9f, 0.4f));
                g_debugDraw.DrawSegment(point1, callback.m_point, b2Color(0.8f, 0.8f, 0.8f));
                b2Vec2 head = callback.m_point + 0.5f * callback.m_normal;
                g_debugDraw.DrawSegment(callback.m_point, head, b2Color(0.9f, 0.9f, 0.4f));
            }
            else
            {
                g_debugDraw.DrawSegment(point1, point2, b2Color(0.8f, 0.8f, 0.8f));
            }
        }
        else if (m_mode == e_multiple)
        {
            RayCastMultipleCallback callback = new RayCastMultipleCallback();
            m_world.RayCast(callback, point1, point2);
            g_debugDraw.DrawSegment(point1, point2, b2Color(0.8f, 0.8f, 0.8f));

            for (int32 i = 0; i < callback.m_count; ++i)
            {
                b2Vec2 p = callback.m_points[i];
                b2Vec2 n = callback.m_normals[i];
                g_debugDraw.DrawPoint(p, 5.0f, b2Color(0.4f, 0.9f, 0.4f));
                g_debugDraw.DrawSegment(point1, p, b2Color(0.8f, 0.8f, 0.8f));
                b2Vec2 head = p + 0.5f * n;
                g_debugDraw.DrawSegment(p, head, b2Color(0.9f, 0.9f, 0.4f));
            }
        }

        if (advanceRay)
        {
            m_angle += 0.25f * b2_pi / 180.0f;
        }
    }

    static Test Create()
    {
        return new typeof(this);
    }

    int32 m_bodyIndex;
    b2Body* m_bodies[e_maxBodies];
    int32 m_userData[e_maxBodies];
    b2PolygonShape m_polygons[4];
    b2CircleShape  m_circle;
    b2EdgeShape m_edge;
    float32 m_angle = 0;
    Mode m_mode;
}
