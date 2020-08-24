void function () {
    var b, f1, list, x;
    x = 3;
    console.log(x);
    list = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10
    ];
    console.log(list);
    f1 = function (n) {
        return n * 2;
    };
    console.log(f1(8));
    b = 99;
    console.log(b);
}.call(this);