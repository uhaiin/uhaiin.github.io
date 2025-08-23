---
layout: post
category: example2
---

<html>
  <head>
    <meta charset="utf-8" />
    <script src="../assets/js/echarts.min.js"></script>
  </head>
  <body>
    <div id="main" style="width: 600px;height:400px;"></div>
    <div id="main2" style="width: 600px;height:400px;"></div>

    <script type="text/javascript">
      var myChart = echarts.init(document.getElementById('main'));
      var option = {
        title: {
          text: 'ECharts Getting Started Example'
        },
        tooltip: {},
        legend: {
          data: ['sales']
        },
        xAxis: {
          data: ['Shirts', 'Cardigans', 'Chiffons', 'Pants', 'Heels', 'Socks']
        },
        yAxis: {},
        series: [
          {
            name: 'sales',
            type: 'bar',
            data: [5, 20, 36, 10, 10, 20]
          }
        ]
      };
      myChart.setOption(option);


      var myChart2 = echarts.init(document.getElementById('main2'));
      var option2 = {

xAxis: {
data: [
'2017-10-24', '2017-10-25', '2017-10-26', '2017-10-27',
'2017-10-28', '2017-10-29', '2017-10-30', '2017-10-31',
'2017-11-01', '2017-11-02', '2017-11-03', '2017-11-04',
'2017-11-05', '2017-11-06', '2017-11-07', '2017-11-08',
'2017-11-09', '2017-11-10', '2017-11-11', '2017-11-12'
]
},
yAxis: {},
series: [
{
type: 'candlestick',
data: [
[20, 34, 10, 38], // 2017-10-24（原始数据）
[40, 35, 30, 50], // 2017-10-25（原始数据）
[31, 38, 33, 44], // 2017-10-26（原始数据）
[38, 15, 5, 42], // 2017-10-27（原始数据）
[18, 25, 12, 30], // 2017-10-28
[26, 40, 22, 45], // 2017-10-29
[39, 32, 28, 41], // 2017-10-30
[33, 48, 30, 52], // 2017-10-31
[47, 29, 25, 50], // 2017-11-01
[30, 36, 27, 40], // 2017-11-02
[35, 22, 18, 38], // 2017-11-03
[23, 31, 20, 35], // 2017-11-04
[32, 45, 29, 48], // 2017-11-05
[44, 38, 35, 46], // 2017-11-06
[39, 52, 36, 55], // 2017-11-07
[51, 37, 33, 53], // 2017-11-08
[38, 44, 35, 47], // 2017-11-09
[43, 28, 24, 45], // 2017-11-10
[29, 39, 26, 42], // 2017-11-11
[40, 25, 20, 43] // 2017-11-12
]
}
]
};

      myChart2.setOption(option2);

    </script>

  </body>
</html>
