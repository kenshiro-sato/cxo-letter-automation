# CxOレター自動化システム

企業向けCxOレターの作成と管理を自動化するMacアプリケーション。Claude APIとPerplexity APIを活用した企業調査、レター生成、PDF変換、Google連携機能を提供します。

## 機能概要

- 企業リストのインポートと処理
- 企業情報の自動調査（Claude & Perplexity API連携）
- レター文面の自動生成と編集
- PDF形式でのレター出力
- Google Sheets/Driveとの連携
- 受領書・依頼リストの自動生成

## 開発環境構築

```bash
# リポジトリのクローン
git clone https://github.com/your-organization/cxo-letter-automation.git
cd cxo-letter-automation

# 開発環境のセットアップ
chmod +x setup.sh
./setup.sh

# 仮想環境のアクティベート
source venv/bin/activate
```

## 実行方法
```bash
# 開発環境での実行
python src/main.py
```

## プロジェクト構成

- `src/`: ソースコード
  - `api/`: API連携モジュール
  - `models/`: データモデル
  - `services/`: ビジネスロジック
  - `integrations/`: 外部サービス連携
  - `ui/`: ユーザーインターフェース
- `templates/`: レターや受領書のテンプレート
- `assets/`: アイコンなどの静的ファイル
- `data/`: 設定・キャッシュデータ
- `output/`: 生成ファイルの出力先

## ライセンス

MIT © Your Organization
