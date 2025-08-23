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
    </script>
  </body>
</html>