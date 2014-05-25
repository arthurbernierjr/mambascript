void function () {
    var battler;
    LimitedValue = function () {
        2;
        3;
        function LimitedValue(current, max) {
            this.current = current;
            this.max = max;
        }
        return LimitedValue;
    }();
    Entity = function () {
        10;
        function Entity() {
            this.id = Math.random().toString();
        }
        return Entity;
    }();
    Battler = function (super$) {
        extends$(Battler, super$);
        16;
        17;
        function Battler() {
            Battler.__super__.constructor.apply(this, arguments);
            this.hp = new LimitedValue(30, 30);
            this.wp = new LimitedValue(0, 30);
        }
        Battler.prototype.updateByEachTurn = function () {
            return this.wp.current += 1;
        };
        return Battler;
    }(Entity);
    battler = new Battler();
    battler.updateByEachTurn();
    console.log(battler);
    function isOwn$(o, p) {
        return {}.hasOwnProperty.call(o, p);
    }
    function extends$(child, parent) {
        for (var key in parent)
            if (isOwn$(parent, key))
                child[key] = parent[key];
        function ctor() {
            this.constructor = child;
        }
        ctor.prototype = parent.prototype;
        child.prototype = new ctor();
        child.__super__ = parent.prototype;
        return child;
    }
}.call(this);