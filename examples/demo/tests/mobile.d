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
module tests.mobile;

import core.stdc.math;

import std.string;
import std.typecons;

import deimos.glfw.glfw3;

import dbox;

import framework.debug_draw;
import framework.test;

class Mobile : Test
{
    enum
    {
        e_depth = 4
    }


    this()
    {
        b2Body* ground;

        // Create ground body_.
        {
            b2BodyDef bodyDef;
            bodyDef.position.Set(0.0f, 20.0f);
            ground = m_world.CreateBody(&bodyDef);
        }

        float32 a = 0.5f;
        b2Vec2 h = b2Vec2(0.0f, a);

        b2Body* root = AddNode(ground, b2Vec2_zero, 0, 3.0f, a);

        b2RevoluteJointDef jointDef = new b2RevoluteJointDef;
        jointDef.bodyA = ground;
        jointDef.bodyB = root;
        jointDef.localAnchorA.SetZero();
        jointDef.localAnchorB = h;
        m_world.CreateJoint(jointDef);
    }

    b2Body* AddNode(b2Body* parent, b2Vec2 localAnchor, int32 depth, float32 offset, float32 a)
    {
        float32 density = 20.0f;
        b2Vec2 h = b2Vec2(0.0f, a);

        b2Vec2 p = parent.GetPosition() + localAnchor - h;

        b2BodyDef bodyDef;
        bodyDef.type     = b2_dynamicBody;
        bodyDef.position = p;
        b2Body* body_ = m_world.CreateBody(&bodyDef);

        auto shape = new b2PolygonShape();
        shape.SetAsBox(0.25f * a, a);
        body_.CreateFixture(shape, density);

        if (depth == e_depth)
        {
            return body_;
        }

        b2Vec2  a1    = b2Vec2(offset, -a);
        b2Vec2  a2    = b2Vec2(-offset, -a);
        b2Body* body1 = AddNode(body_, a1, depth + 1, 0.5f * offset, a);
        b2Body* body2 = AddNode(body_, a2, depth + 1, 0.5f * offset, a);

        b2RevoluteJointDef jointDef = new b2RevoluteJointDef();
        jointDef.bodyA        = body_;
        jointDef.localAnchorB = h;

        jointDef.localAnchorA = a1;
        jointDef.bodyB        = body1;
        m_world.CreateJoint(jointDef);

        jointDef.localAnchorA = a2;
        jointDef.bodyB        = body2;
        m_world.CreateJoint(jointDef);

        return body_;
    }

    static Test Create()
    {
        return new typeof(this);
    }
}
