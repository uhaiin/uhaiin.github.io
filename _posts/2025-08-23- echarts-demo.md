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
'2025-08-13', '2025-08-14','2025-08-15', '2025-08-18','2025-08-19', '2025-08-20','2025-08-21', '2025-08-22'
]
},
yAxis: {},
series: [
{
type: 'candlestick',
data: [
[0.01, 0.01, -0.86, 1.73],
[-0.43, -1.55, -1.56, 0.01],
[0.00, 0.29, -0.05, 0.49],
[0.00, 1.25, -0.78, 2.07],
[-0.01, 1.02, -0.01, 2.18],
[-0.64, 0.07, -1.62, 0.16],
[-0.64, 0.07, -1.29, 0.23],
[0.92, 1.82, 0.92, 1.95]
]
}
]
};

      myChart2.setOption(option2);

    </script>

  </body>
</html>
