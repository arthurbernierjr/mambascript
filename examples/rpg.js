void function () {
    var _uid, createGolbin;
    1;
    7;
    19;
    _uid = 0;
    createGolbin = function (lv, group_id) {
        return {
            name: 'Goblin',
            uid: _uid++,
            group_id: group_id,
            lv: lv,
            hp: 30,
            max_hp: 30,
            wt: 0,
            max_wt: 20,
            status: {
                str: 5 + lv,
                int: 2 + ~~(lv / 3),
                dex: 2 + ~~(lv / 2)
            }
        };
    };
    console.log('fooo');
}.call(this);