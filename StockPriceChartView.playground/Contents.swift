//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport


class StockPriceChartView: UIView {

    let stockPriceChart: StockPriceChart

    var stockPriceLineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemBlue.cgColor
        layer.lineWidth = 1
        return layer
    }()

    var stockPriceGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [UIColor.systemBlue.cgColor, UIColor.clear.cgColor]
        return layer
    }()

    var stockPriceMaskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        return layer
    }()

    init(stockPriceChart: StockPriceChart) {
        self.stockPriceChart = stockPriceChart
        super.init(frame: .zero)

        backgroundColor = .systemBackground

        stockPriceGradientLayer.mask = stockPriceMaskLayer
        layer.addSublayer(stockPriceGradientLayer)
        layer.addSublayer(stockPriceLineLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)

        setPathsToLayers()
        stockPriceGradientLayer.frame = bounds
    }

    private func setPathsToLayers() {
        let linePath = stockPriceLinePath()
        let fillPath = stockPriceFillPath(stockPriceLinePath: linePath)
        stockPriceLineLayer.path = linePath.cgPath
        stockPriceMaskLayer.path = fillPath.cgPath
    }

    func stockPriceLinePath() -> UIBezierPath {
        let path = UIBezierPath()
        guard let openToday = stockPriceChart.marketOpenTime,
              let closeToday = stockPriceChart.marketCloseTime else {
            return UIBezierPath()
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var isFirst = true
        for timeSeries in stockPriceChart.timeSerieses {
            let time = dateFormatter.date(from: timeSeries.time)
            if let time = time, time >= openToday, time <= closeToday {
                let xCoordinate = CGFloat(time.timeIntervalSince(openToday) / 60) * xDivision(open: openToday, close: closeToday)
                let yCoordinate = frame.height - ((CGFloat(Float(timeSeries.open) ?? 0) - stockPriceChart.lowestPrice) * yDivision(highestPrice: stockPriceChart.highestPrice, lowestPrice: stockPriceChart.lowestPrice))
                if isFirst {
                    path.move(to: CGPoint(x: xCoordinate, y: yCoordinate))
                    isFirst = false
                } else {
                    path.addLine(to: CGPoint(x: xCoordinate, y: yCoordinate))
                }
            }
        }
        return path
    }

    private func stockPriceFillPath(stockPriceLinePath: UIBezierPath) -> UIBezierPath {
        let path = stockPriceLinePath.copy() as? UIBezierPath
        guard let fillPath = path else {
            return UIBezierPath()
        }
        fillPath.addLine(to: CGPoint(x: fillPath.currentPoint.x, y: frame.height))
        fillPath.addLine(to: CGPoint(x: 0, y: frame.height))
        fillPath.close()
        return fillPath
    }

    private func xDivision(open: Date?, close: Date?) -> CGFloat {
        guard let open = open, let close = close else {
            return 0
        }
        return frame.width / (CGFloat(close.timeIntervalSince(open) / 60))
    }

    private func yDivision(highestPrice: CGFloat, lowestPrice: CGFloat) -> CGFloat {
        return frame.height / (highestPrice - lowestPrice)
    }

}


class StockPriceChart {

    var highestPrice: CGFloat = 0
    var lowestPrice: CGFloat = 0
    var timeSerieses: [TimeSeries] = []

    var marketOpenTime: Date? {
        let dateComponents = DateComponents(year: 2020,
                                            month: 12,
                                            day: 4,
                                            hour: 9,
                                            minute: 30)
        return Calendar.current.date(from: dateComponents)
    }

    var marketCloseTime: Date? {
        let dateComponents = DateComponents(year: 2020,
                                            month: 12,
                                            day: 4,
                                            hour: 16,
                                            minute: 0)
        return Calendar.current.date(from: dateComponents)
    }

    init(jsonString: String) {
        let decoded = try! JSONDecoder().decode(TimeSeriesContainer.self, from: Data(jsonString.utf8))
        timeSerieses = decoded.timeSeries5min.array.sorted { $0.time < $1.time }

        let openPrices = timeSerieses.compactMap { $0.open }
        if let highestString = openPrices.max(), let highest = Float(highestString) {
            highestPrice = CGFloat(highest)
        }
        if let lowestString = openPrices.min(), let lowest = Float(lowestString) {
            lowestPrice = CGFloat(lowest)
        }
    }

}


// Present the view controller in the Live View window


struct DecodedArray<T: Decodable>: Decodable {

    typealias DecodedArrayType = [T]
     var array: DecodedArrayType

    private struct DynamicCodingKeys: CodingKey {

        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }

    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var tempArray: DecodedArrayType = []
        for key in container.allKeys {
            let decodedObject = try container.decode(T.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            tempArray.append(decodedObject)
        }
        array = tempArray

    }
}
struct TimeSeriesContainer: Decodable {

    let timeSeries5min: DecodedArray<TimeSeries>

    enum CodingKeys: String, CodingKey {
        case timeSeries5min = "Time Series (5min)"
    }
}
struct TimeSeries: Decodable {

    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String

    let time: String

    enum CodingKeys: String, CodingKey {
        case open = "1. open"
        case high = "2. high"
        case low = "3. low"
        case close = "4. close"
        case volume = "5. volume"
        case time
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)

        open = try container.decode(String.self, forKey: CodingKeys.open)
        high = try container.decode(String.self, forKey: CodingKeys.high)
        low = try container.decode(String.self, forKey: CodingKeys.low)
        close = try container.decode(String.self, forKey: CodingKeys.close)
        volume = try container.decode(String.self, forKey: CodingKeys.volume)

        time = container.codingPath[1].stringValue
    }

}

var jsonString: String { """
{
    "Meta Data": {
        "1. Information": "Intraday (5min) open, high, low, close prices and volume",
        "2. Symbol": "IBM",
        "3. Last Refreshed": "2020-12-04 19:25:00",
        "4. Interval": "5min",
        "5. Output Size": "Compact",
        "6. Time Zone": "US/Eastern"
    },
    "Time Series (5min)": {
        "2020-12-04 19:25:00": {
            "1. open": "127.1000",
            "2. high": "127.1000",
            "3. low": "127.1000",
            "4. close": "127.1000",
            "5. volume": "300"
        },
        "2020-12-04 19:20:00": {
            "1. open": "127.1000",
            "2. high": "127.1900",
            "3. low": "127.1000",
            "4. close": "127.1900",
            "5. volume": "901"
        },
        "2020-12-04 19:15:00": {
            "1. open": "127.1000",
            "2. high": "127.1000",
            "3. low": "127.1000",
            "4. close": "127.1000",
            "5. volume": "200"
        },
        "2020-12-04 19:10:00": {
            "1. open": "127.1900",
            "2. high": "127.1900",
            "3. low": "127.1900",
            "4. close": "127.1900",
            "5. volume": "500"
        },
        "2020-12-04 17:30:00": {
            "1. open": "127.0500",
            "2. high": "127.0500",
            "3. low": "127.0500",
            "4. close": "127.0500",
            "5. volume": "200"
        },
        "2020-12-04 17:20:00": {
            "1. open": "127.1800",
            "2. high": "127.1900",
            "3. low": "127.1800",
            "4. close": "127.1900",
            "5. volume": "500"
        },
        "2020-12-04 17:15:00": {
            "1. open": "127.2000",
            "2. high": "127.2000",
            "3. low": "127.2000",
            "4. close": "127.2000",
            "5. volume": "2979"
        },
        "2020-12-04 17:00:00": {
            "1. open": "127.0500",
            "2. high": "127.1900",
            "3. low": "127.0500",
            "4. close": "127.1900",
            "5. volume": "400"
        },
        "2020-12-04 16:10:00": {
            "1. open": "127.1873",
            "2. high": "127.1873",
            "3. low": "127.1873",
            "4. close": "127.1873",
            "5. volume": "3056"
        },
        "2020-12-04 16:05:00": {
            "1. open": "127.2000",
            "2. high": "127.2000",
            "3. low": "127.2000",
            "4. close": "127.2000",
            "5. volume": "189758"
        },
        "2020-12-04 16:00:00": {
            "1. open": "127.1750",
            "2. high": "127.2200",
            "3. low": "127.0500",
            "4. close": "127.1700",
            "5. volume": "262149"
        },
        "2020-12-04 15:55:00": {
            "1. open": "127.0500",
            "2. high": "127.2000",
            "3. low": "127.0100",
            "4. close": "127.1750",
            "5. volume": "144602"
        },
        "2020-12-04 15:50:00": {
            "1. open": "127.1800",
            "2. high": "127.2100",
            "3. low": "127.0550",
            "4. close": "127.0600",
            "5. volume": "89369"
        },
        "2020-12-04 15:45:00": {
            "1. open": "127.0350",
            "2. high": "127.1900",
            "3. low": "127.0000",
            "4. close": "127.1850",
            "5. volume": "70988"
        },
        "2020-12-04 15:40:00": {
            "1. open": "127.1600",
            "2. high": "127.1800",
            "3. low": "126.9900",
            "4. close": "127.0350",
            "5. volume": "72785"
        },
        "2020-12-04 15:35:00": {
            "1. open": "127.0400",
            "2. high": "127.1900",
            "3. low": "127.0100",
            "4. close": "127.1550",
            "5. volume": "56096"
        },
        "2020-12-04 15:30:00": {
            "1. open": "127.1000",
            "2. high": "127.1200",
            "3. low": "126.9500",
            "4. close": "127.0360",
            "5. volume": "78192"
        },
        "2020-12-04 15:25:00": {
            "1. open": "127.0200",
            "2. high": "127.1502",
            "3. low": "127.0000",
            "4. close": "127.1050",
            "5. volume": "55752"
        },
        "2020-12-04 15:20:00": {
            "1. open": "127.0100",
            "2. high": "127.1000",
            "3. low": "126.9900",
            "4. close": "127.0300",
            "5. volume": "47273"
        },
        "2020-12-04 15:15:00": {
            "1. open": "127.0611",
            "2. high": "127.1000",
            "3. low": "127.0100",
            "4. close": "127.0190",
            "5. volume": "24051"
        },
        "2020-12-04 15:10:00": {
            "1. open": "127.0750",
            "2. high": "127.0898",
            "3. low": "126.9800",
            "4. close": "127.0650",
            "5. volume": "42526"
        },
        "2020-12-04 15:05:00": {
            "1. open": "127.1900",
            "2. high": "127.2100",
            "3. low": "127.0500",
            "4. close": "127.0800",
            "5. volume": "29511"
        },
        "2020-12-04 15:00:00": {
            "1. open": "127.1900",
            "2. high": "127.2416",
            "3. low": "127.1578",
            "4. close": "127.1700",
            "5. volume": "32305"
        },
        "2020-12-04 14:55:00": {
            "1. open": "127.2900",
            "2. high": "127.3200",
            "3. low": "127.1600",
            "4. close": "127.1900",
            "5. volume": "50137"
        },
        "2020-12-04 14:50:00": {
            "1. open": "127.2400",
            "2. high": "127.3800",
            "3. low": "127.1700",
            "4. close": "127.2913",
            "5. volume": "69164"
        },
        "2020-12-04 14:45:00": {
            "1. open": "127.0300",
            "2. high": "127.2400",
            "3. low": "127.0200",
            "4. close": "127.2400",
            "5. volume": "42089"
        },
        "2020-12-04 14:40:00": {
            "1. open": "127.0400",
            "2. high": "127.0850",
            "3. low": "127.0000",
            "4. close": "127.0347",
            "5. volume": "57033"
        },
        "2020-12-04 14:35:00": {
            "1. open": "127.0600",
            "2. high": "127.1300",
            "3. low": "126.9950",
            "4. close": "127.0400",
            "5. volume": "60431"
        },
        "2020-12-04 14:30:00": {
            "1. open": "127.0100",
            "2. high": "127.1000",
            "3. low": "126.9500",
            "4. close": "127.0650",
            "5. volume": "66753"
        },
        "2020-12-04 14:25:00": {
            "1. open": "126.9600",
            "2. high": "127.0300",
            "3. low": "126.9500",
            "4. close": "127.0000",
            "5. volume": "55579"
        },
        "2020-12-04 14:20:00": {
            "1. open": "126.7500",
            "2. high": "126.9700",
            "3. low": "126.7400",
            "4. close": "126.9600",
            "5. volume": "65017"
        },
        "2020-12-04 14:15:00": {
            "1. open": "126.6800",
            "2. high": "126.7452",
            "3. low": "126.6100",
            "4. close": "126.7452",
            "5. volume": "45552"
        },
        "2020-12-04 14:10:00": {
            "1. open": "126.8400",
            "2. high": "126.8550",
            "3. low": "126.6750",
            "4. close": "126.6822",
            "5. volume": "38135"
        },
        "2020-12-04 14:05:00": {
            "1. open": "126.8300",
            "2. high": "126.9200",
            "3. low": "126.8100",
            "4. close": "126.8400",
            "5. volume": "46831"
        },
        "2020-12-04 14:00:00": {
            "1. open": "126.8600",
            "2. high": "126.9200",
            "3. low": "126.7700",
            "4. close": "126.8550",
            "5. volume": "45261"
        },
        "2020-12-04 13:55:00": {
            "1. open": "127.0500",
            "2. high": "127.1000",
            "3. low": "126.8600",
            "4. close": "126.8708",
            "5. volume": "73121"
        },
        "2020-12-04 13:50:00": {
            "1. open": "126.9300",
            "2. high": "127.1000",
            "3. low": "126.9200",
            "4. close": "127.0406",
            "5. volume": "63900"
        },
        "2020-12-04 13:45:00": {
            "1. open": "126.9411",
            "2. high": "127.0250",
            "3. low": "126.9200",
            "4. close": "126.9200",
            "5. volume": "146572"
        },
        "2020-12-04 13:40:00": {
            "1. open": "126.7700",
            "2. high": "126.9450",
            "3. low": "126.7700",
            "4. close": "126.9400",
            "5. volume": "75058"
        },
        "2020-12-04 13:35:00": {
            "1. open": "126.6300",
            "2. high": "126.8500",
            "3. low": "126.6300",
            "4. close": "126.7700",
            "5. volume": "75820"
        },
        "2020-12-04 13:30:00": {
            "1. open": "126.8649",
            "2. high": "126.8649",
            "3. low": "126.6200",
            "4. close": "126.6300",
            "5. volume": "67934"
        },
        "2020-12-04 13:25:00": {
            "1. open": "126.9750",
            "2. high": "127.0199",
            "3. low": "126.8600",
            "4. close": "126.8600",
            "5. volume": "86858"
        },
        "2020-12-04 13:20:00": {
            "1. open": "126.9183",
            "2. high": "127.0500",
            "3. low": "126.8700",
            "4. close": "126.9800",
            "5. volume": "131055"
        },
        "2020-12-04 13:15:00": {
            "1. open": "126.7100",
            "2. high": "126.9500",
            "3. low": "126.6978",
            "4. close": "126.9200",
            "5. volume": "95802"
        },
        "2020-12-04 13:10:00": {
            "1. open": "126.6300",
            "2. high": "126.7700",
            "3. low": "126.5250",
            "4. close": "126.7100",
            "5. volume": "104753"
        },
        "2020-12-04 13:05:00": {
            "1. open": "126.1550",
            "2. high": "126.6600",
            "3. low": "126.1500",
            "4. close": "126.6400",
            "5. volume": "250718"
        },
        "2020-12-04 13:00:00": {
            "1. open": "126.0250",
            "2. high": "126.2251",
            "3. low": "125.9100",
            "4. close": "126.1698",
            "5. volume": "175987"
        },
        "2020-12-04 12:55:00": {
            "1. open": "126.0100",
            "2. high": "126.0500",
            "3. low": "125.9300",
            "4. close": "126.0200",
            "5. volume": "35745"
        },
        "2020-12-04 12:50:00": {
            "1. open": "126.0000",
            "2. high": "126.0500",
            "3. low": "125.9650",
            "4. close": "125.9900",
            "5. volume": "30382"
        },
        "2020-12-04 12:45:00": {
            "1. open": "125.9520",
            "2. high": "126.0700",
            "3. low": "125.9300",
            "4. close": "125.9900",
            "5. volume": "33709"
        },
        "2020-12-04 12:40:00": {
            "1. open": "125.9106",
            "2. high": "126.0900",
            "3. low": "125.9000",
            "4. close": "125.9600",
            "5. volume": "93123"
        },
        "2020-12-04 12:35:00": {
            "1. open": "125.8200",
            "2. high": "125.9300",
            "3. low": "125.8200",
            "4. close": "125.9100",
            "5. volume": "35499"
        },
        "2020-12-04 12:30:00": {
            "1. open": "125.6000",
            "2. high": "125.8150",
            "3. low": "125.5911",
            "4. close": "125.8100",
            "5. volume": "46375"
        },
        "2020-12-04 12:25:00": {
            "1. open": "125.5600",
            "2. high": "125.6000",
            "3. low": "125.5000",
            "4. close": "125.6000",
            "5. volume": "27368"
        },
        "2020-12-04 12:20:00": {
            "1. open": "125.6880",
            "2. high": "125.7083",
            "3. low": "125.5500",
            "4. close": "125.5700",
            "5. volume": "36315"
        },
        "2020-12-04 12:15:00": {
            "1. open": "125.7711",
            "2. high": "125.8000",
            "3. low": "125.6600",
            "4. close": "125.6796",
            "5. volume": "19225"
        },
        "2020-12-04 12:10:00": {
            "1. open": "125.6550",
            "2. high": "125.7900",
            "3. low": "125.6500",
            "4. close": "125.7699",
            "5. volume": "36379"
        },
        "2020-12-04 12:05:00": {
            "1. open": "125.6432",
            "2. high": "125.7150",
            "3. low": "125.5900",
            "4. close": "125.6800",
            "5. volume": "37520"
        },
        "2020-12-04 12:00:00": {
            "1. open": "125.6493",
            "2. high": "125.7000",
            "3. low": "125.6300",
            "4. close": "125.6381",
            "5. volume": "36999"
        },
        "2020-12-04 11:55:00": {
            "1. open": "125.5360",
            "2. high": "125.6670",
            "3. low": "125.4700",
            "4. close": "125.6670",
            "5. volume": "27389"
        },
        "2020-12-04 11:50:00": {
            "1. open": "125.6700",
            "2. high": "125.6900",
            "3. low": "125.3800",
            "4. close": "125.5039",
            "5. volume": "29231"
        },
        "2020-12-04 11:45:00": {
            "1. open": "125.5400",
            "2. high": "125.7500",
            "3. low": "125.5200",
            "4. close": "125.6400",
            "5. volume": "44345"
        },
        "2020-12-04 11:40:00": {
            "1. open": "125.5700",
            "2. high": "125.6700",
            "3. low": "125.5100",
            "4. close": "125.5500",
            "5. volume": "52555"
        },
        "2020-12-04 11:35:00": {
            "1. open": "125.4200",
            "2. high": "125.6100",
            "3. low": "125.3800",
            "4. close": "125.5600",
            "5. volume": "56824"
        },
        "2020-12-04 11:30:00": {
            "1. open": "125.3400",
            "2. high": "125.4800",
            "3. low": "125.2900",
            "4. close": "125.4101",
            "5. volume": "47239"
        },
        "2020-12-04 11:25:00": {
            "1. open": "125.3200",
            "2. high": "125.3600",
            "3. low": "125.2100",
            "4. close": "125.3600",
            "5. volume": "40378"
        },
        "2020-12-04 11:20:00": {
            "1. open": "125.4000",
            "2. high": "125.4800",
            "3. low": "125.3300",
            "4. close": "125.3300",
            "5. volume": "40356"
        },
        "2020-12-04 11:15:00": {
            "1. open": "125.3500",
            "2. high": "125.4600",
            "3. low": "125.3500",
            "4. close": "125.4000",
            "5. volume": "46568"
        },
        "2020-12-04 11:10:00": {
            "1. open": "125.2300",
            "2. high": "125.3400",
            "3. low": "125.2240",
            "4. close": "125.3400",
            "5. volume": "29988"
        },
        "2020-12-04 11:05:00": {
            "1. open": "125.2500",
            "2. high": "125.3300",
            "3. low": "125.2100",
            "4. close": "125.2200",
            "5. volume": "30889"
        },
        "2020-12-04 11:00:00": {
            "1. open": "125.2300",
            "2. high": "125.3100",
            "3. low": "125.1900",
            "4. close": "125.2600",
            "5. volume": "29888"
        },
        "2020-12-04 10:55:00": {
            "1. open": "125.3001",
            "2. high": "125.3800",
            "3. low": "125.1900",
            "4. close": "125.2200",
            "5. volume": "33076"
        },
        "2020-12-04 10:50:00": {
            "1. open": "125.3600",
            "2. high": "125.4200",
            "3. low": "125.2900",
            "4. close": "125.3100",
            "5. volume": "51858"
        },
        "2020-12-04 10:45:00": {
            "1. open": "125.2800",
            "2. high": "125.3500",
            "3. low": "125.1600",
            "4. close": "125.3500",
            "5. volume": "45981"
        },
        "2020-12-04 10:40:00": {
            "1. open": "125.0780",
            "2. high": "125.2600",
            "3. low": "125.0000",
            "4. close": "125.2300",
            "5. volume": "57782"
        },
        "2020-12-04 10:35:00": {
            "1. open": "125.1050",
            "2. high": "125.1500",
            "3. low": "124.9800",
            "4. close": "125.0800",
            "5. volume": "45469"
        },
        "2020-12-04 10:30:00": {
            "1. open": "124.9400",
            "2. high": "125.1200",
            "3. low": "124.8400",
            "4. close": "125.1150",
            "5. volume": "32178"
        },
        "2020-12-04 10:25:00": {
            "1. open": "124.9000",
            "2. high": "125.0300",
            "3. low": "124.7500",
            "4. close": "124.9100",
            "5. volume": "81384"
        },
        "2020-12-04 10:20:00": {
            "1. open": "124.6400",
            "2. high": "124.9500",
            "3. low": "124.5800",
            "4. close": "124.9243",
            "5. volume": "55656"
        },
        "2020-12-04 10:15:00": {
            "1. open": "124.5900",
            "2. high": "124.6300",
            "3. low": "124.3800",
            "4. close": "124.6300",
            "5. volume": "46800"
        },
        "2020-12-04 10:10:00": {
            "1. open": "124.6050",
            "2. high": "124.7400",
            "3. low": "124.5700",
            "4. close": "124.6645",
            "5. volume": "33749"
        },
        "2020-12-04 10:05:00": {
            "1. open": "124.3500",
            "2. high": "124.6286",
            "3. low": "124.3400",
            "4. close": "124.6100",
            "5. volume": "30898"
        },
        "2020-12-04 10:00:00": {
            "1. open": "124.6271",
            "2. high": "124.7600",
            "3. low": "124.3500",
            "4. close": "124.3900",
            "5. volume": "64153"
        },
        "2020-12-04 09:55:00": {
            "1. open": "124.5430",
            "2. high": "124.6900",
            "3. low": "124.4540",
            "4. close": "124.6400",
            "5. volume": "37294"
        },
        "2020-12-04 09:50:00": {
            "1. open": "124.7300",
            "2. high": "124.8100",
            "3. low": "124.5296",
            "4. close": "124.5296",
            "5. volume": "50052"
        },
        "2020-12-04 09:45:00": {
            "1. open": "124.4000",
            "2. high": "124.8000",
            "3. low": "124.4000",
            "4. close": "124.7000",
            "5. volume": "50773"
        },
        "2020-12-04 09:40:00": {
            "1. open": "124.2300",
            "2. high": "124.6150",
            "3. low": "124.2200",
            "4. close": "124.4400",
            "5. volume": "50249"
        },
        "2020-12-04 09:35:00": {
            "1. open": "123.9700",
            "2. high": "124.3130",
            "3. low": "123.6400",
            "4. close": "124.2100",
            "5. volume": "213093"
        },
        "2020-12-04 09:30:00": {
            "1. open": "123.9500",
            "2. high": "124.1800",
            "3. low": "123.9400",
            "4. close": "124.1800",
            "5. volume": "2278"
        },
        "2020-12-04 09:25:00": {
            "1. open": "123.9500",
            "2. high": "124.1800",
            "3. low": "123.9400",
            "4. close": "124.1800",
            "5. volume": "2278"
        },
        "2020-12-04 09:00:00": {
            "1. open": "124.0000",
            "2. high": "124.1800",
            "3. low": "124.0000",
            "4. close": "124.1800",
            "5. volume": "772"
        },
        "2020-12-04 07:05:00": {
            "1. open": "123.9300",
            "2. high": "123.9300",
            "3. low": "123.9300",
            "4. close": "123.9300",
            "5. volume": "165"
        },
        "2020-12-03 18:35:00": {
            "1. open": "123.7100",
            "2. high": "123.7100",
            "3. low": "123.7100",
            "4. close": "123.7100",
            "5. volume": "266"
        },
        "2020-12-03 18:15:00": {
            "1. open": "123.9300",
            "2. high": "123.9300",
            "3. low": "123.9300",
            "4. close": "123.9300",
            "5. volume": "100"
        },
        "2020-12-03 17:30:00": {
            "1. open": "124.1600",
            "2. high": "124.1600",
            "3. low": "124.1600",
            "4. close": "124.1600",
            "5. volume": "2969"
        },
        "2020-12-03 16:55:00": {
            "1. open": "123.6100",
            "2. high": "123.6100",
            "3. low": "123.6100",
            "4. close": "123.6100",
            "5. volume": "1596"
        },
        "2020-12-03 16:40:00": {
            "1. open": "123.6400",
            "2. high": "123.6400",
            "3. low": "123.6300",
            "4. close": "123.6300",
            "5. volume": "300"
        },
        "2020-12-03 16:35:00": {
            "1. open": "124.0000",
            "2. high": "124.0000",
            "3. low": "123.6100",
            "4. close": "123.6100",
            "5. volume": "6839"
        },
        "2020-12-03 16:30:00": {
            "1. open": "124.0100",
            "2. high": "124.0100",
            "3. low": "124.0000",
            "4. close": "124.0000",
            "5. volume": "2000"
        },
        "2020-12-03 16:20:00": {
            "1. open": "124.0000",
            "2. high": "124.0000",
            "3. low": "124.0000",
            "4. close": "124.0000",
            "5. volume": "790"
        },
        "2020-12-03 16:15:00": {
            "1. open": "123.7500",
            "2. high": "124.0000",
            "3. low": "123.7500",
            "4. close": "124.0000",
            "5. volume": "5044"
        }
    }
}
"""}
let stockPriceChart = StockPriceChart(jsonString: jsonString)
let view = StockPriceChartView(stockPriceChart: stockPriceChart)
view.frame = CGRect(x: 0, y: 0, width: 390, height: 844 / 3)

PlaygroundPage.current.liveView = view
