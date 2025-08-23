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
 [0.01, 0.01, -0.86, 1.73],   // 第1天 (保持不变)
  [-0.42, -1.54, -1.55, 0.02], // 第2天 + 第1天收盘价(0.01)
  [-1.54, -1.26, -1.60, -1.06],// 第3天 + 第2天收盘价(-1.55)
  [-1.26, -0.30, -2.33, 0.52], // 第4天 + 第3天收盘价(0.29)
  [-0.30, 1.32, -0.30, 2.37],  // 第5天 + 第4天收盘价(1.25)
  [1.01, 1.09, 0.03, 1.24],    // 第6天 + 第5天收盘价(1.02)
  [1.09, 1.16, 0.36, 1.29],    // 第7天 + 第6天收盘价(0.07)
  [1.16, 3.64, 1.16, 3.77] 
]
}
]
};

      myChart2.setOption(option2);

    </script>

  </body>
</html>
