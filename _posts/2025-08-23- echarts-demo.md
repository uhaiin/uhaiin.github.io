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
'2017-10-24', '2017-10-25'
]
},
yAxis: {},
series: [
{
type: 'candlestick',
data: [
[0.01%, 0.01%, -0.86%, 1.73%],
[-0.43%, -1.55%, -1.56%, 0.01%]
]
}
]
};

      myChart2.setOption(option2);

    </script>

  </body>
</html>
