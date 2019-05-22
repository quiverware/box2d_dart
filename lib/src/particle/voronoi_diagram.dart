/*******************************************************************************
 * Copyright (c) 2015, Daniel Murphy, Google
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 ******************************************************************************/

part of box2d;

abstract class VoronoiDiagramCallback {
  void callback(int aTag, int bTag, int cTag);
}

class VoronoiGenerator {
  final Vector2 center = Vector2.zero();
  int tag = 0;
}

class VoronoiDiagramTask {
  VoronoiDiagramTask(int x, int y, int i, VoronoiGenerator g) {
    _x = x;
    _y = y;
    _i = i;
    _generator = g;
  }

  VoronoiDiagramTask.zero();

  int _x = 0, _y = 0, _i = 0;

  VoronoiGenerator _generator;

  VoronoiDiagramTask set(int x, int y, int i, VoronoiGenerator g) {
    _x = x;
    _y = y;
    _i = i;
    _generator = g;
    return this;
  }
}

class VoronoiDiagramTaskMutableStack extends MutableStack<VoronoiDiagramTask> {
  VoronoiDiagramTaskMutableStack(int size) : super(size);

  @override
  VoronoiDiagramTask newInstance() {
    return VoronoiDiagramTask.zero();
  }
}

class VoronoiDiagram {
  VoronoiDiagram(int generatorCapacity) {
    _generatorBuffer = List<VoronoiGenerator>(generatorCapacity);
    for (int i = 0; i < generatorCapacity; i++) {
      _generatorBuffer[i] = VoronoiGenerator();
    }
    _generatorCount = 0;
    _countX = 0;
    _countY = 0;
    _diagram = null;
  }

  List<VoronoiGenerator> _generatorBuffer;
  int _generatorCount = 0;
  int _countX = 0, _countY = 0;

  // The diagram is an array of "pointers".
  List<VoronoiGenerator> _diagram;

  void getNodes(VoronoiDiagramCallback callback) {
    for (int y = 0; y < _countY - 1; y++) {
      for (int x = 0; x < _countX - 1; x++) {
        final int i = x + y * _countX;
        final VoronoiGenerator a = _diagram[i];
        final VoronoiGenerator b = _diagram[i + 1];
        final VoronoiGenerator c = _diagram[i + _countX];
        final VoronoiGenerator d = _diagram[i + 1 + _countX];
        if (b != c) {
          if (a != b && a != c) {
            callback.callback(a.tag, b.tag, c.tag);
          }
          if (d != b && d != c) {
            callback.callback(b.tag, d.tag, c.tag);
          }
        }
      }
    }
  }

  void addGenerator(Vector2 center, int tag) {
    _generatorBuffer[_generatorCount++]
      ..center.x = center.x
      ..center.y = center.y
      ..tag = tag;
  }

  final Vector2 _lower = Vector2.zero();
  final Vector2 _upper = Vector2.zero();
  final MutableStack<VoronoiDiagramTask> _taskPool =
      VoronoiDiagramTaskMutableStack(50);

  final StackQueue<VoronoiDiagramTask> _queue =
      StackQueue<VoronoiDiagramTask>();

  void generate(double radius) {
    assert(_diagram == null);
    final double inverseRadius = 1 / radius;
    _lower.x = double.maxFinite;
    _lower.y = double.maxFinite;
    _upper.x = -double.maxFinite;
    _upper.y = -double.maxFinite;
    for (int k = 0; k < _generatorCount; k++) {
      final VoronoiGenerator g = _generatorBuffer[k];
      Vector2.min(_lower, g.center, _lower);
      Vector2.max(_upper, g.center, _upper);
    }
    _countX = 1 + (inverseRadius * (_upper.x - _lower.x)).toInt();
    _countY = 1 + (inverseRadius * (_upper.y - _lower.y)).toInt();
    _diagram = List<VoronoiGenerator>(_countX * _countY);
    _queue.reset(List<VoronoiDiagramTask>(4 * _countX * _countX));
    for (int k = 0; k < _generatorCount; k++) {
      final VoronoiGenerator g = _generatorBuffer[k];
      g.center.x = inverseRadius * (g.center.x - _lower.x);
      g.center.y = inverseRadius * (g.center.y - _lower.y);
      final int x = math.max(0, math.min(g.center.x.toInt(), _countX - 1));
      final int y = math.max(0, math.min(g.center.y.toInt(), _countY - 1));
      _queue.push(_taskPool.pop().set(x, y, x + y * _countX, g));
    }
    while (!_queue.empty()) {
      final VoronoiDiagramTask front = _queue.pop();
      final int x = front._x;
      final int y = front._y;
      final int i = front._i;
      final VoronoiGenerator g = front._generator;
      if (_diagram[i] == null) {
        _diagram[i] = g;
        if (x > 0) {
          _queue.push(_taskPool.pop().set(x - 1, y, i - 1, g));
        }
        if (y > 0) {
          _queue.push(_taskPool.pop().set(x, y - 1, i - _countX, g));
        }
        if (x < _countX - 1) {
          _queue.push(_taskPool.pop().set(x + 1, y, i + 1, g));
        }
        if (y < _countY - 1) {
          _queue.push(_taskPool.pop().set(x, y + 1, i + _countX, g));
        }
      }
      _taskPool.push(front);
    }
    final int maxIteration = _countX + _countY;
    for (int iteration = 0; iteration < maxIteration; iteration++) {
      for (int y = 0; y < _countY; y++) {
        for (int x = 0; x < _countX - 1; x++) {
          final int i = x + y * _countX;
          final VoronoiGenerator a = _diagram[i];
          final VoronoiGenerator b = _diagram[i + 1];
          if (a != b) {
            _queue.push(_taskPool.pop().set(x, y, i, b));
            _queue.push(_taskPool.pop().set(x + 1, y, i + 1, a));
          }
        }
      }
      for (int y = 0; y < _countY - 1; y++) {
        for (int x = 0; x < _countX; x++) {
          final int i = x + y * _countX;
          final VoronoiGenerator a = _diagram[i];
          final VoronoiGenerator b = _diagram[i + _countX];
          if (a != b) {
            _queue.push(_taskPool.pop().set(x, y, i, b));
            _queue.push(_taskPool.pop().set(x, y + 1, i + _countX, a));
          }
        }
      }
      bool updated = false;
      while (!_queue.empty()) {
        final VoronoiDiagramTask front = _queue.pop();
        final int x = front._x;
        final int y = front._y;
        final int i = front._i;
        final VoronoiGenerator k = front._generator;
        final VoronoiGenerator a = _diagram[i];
        final VoronoiGenerator b = k;
        if (a != b) {
          final double ax = a.center.x - x;
          final double ay = a.center.y - y;
          final double bx = b.center.x - x;
          final double by = b.center.y - y;
          final double a2 = ax * ax + ay * ay;
          final double b2 = bx * bx + by * by;
          if (a2 > b2) {
            _diagram[i] = b;
            if (x > 0) {
              _queue.push(_taskPool.pop().set(x - 1, y, i - 1, b));
            }
            if (y > 0) {
              _queue.push(_taskPool.pop().set(x, y - 1, i - _countX, b));
            }
            if (x < _countX - 1) {
              _queue.push(_taskPool.pop().set(x + 1, y, i + 1, b));
            }
            if (y < _countY - 1) {
              _queue.push(_taskPool.pop().set(x, y + 1, i + _countX, b));
            }
            updated = true;
          }
        }
        _taskPool.push(front);
      }
      if (!updated) {
        break;
      }
    }
  }
}
