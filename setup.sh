#!/bin/bash
# CxOレター自動化システム - 開発環境セットアップスクリプト

echo "CxOレター自動化システム - 開発環境をセットアップします"

# Python環境確認
python_version=$(python3 --version 2>&1)
if [[ $? -ne 0 ]]; then
    echo "エラー: Python3がインストールされていません"
    echo "https://www.python.org/downloads/ からインストールしてください"
    exit 1
fi
echo "Python: $python_version"

# 仮想環境の作成
if [ ! -d "venv" ]; then
    echo "Pythonの仮想環境を作成しています..."
    python3 -m venv venv
    if [[ $? -ne 0 ]]; then
        echo "エラー: 仮想環境の作成に失敗しました"
        exit 1
    fi
fi

# 仮想環境をアクティベート
source venv/bin/activate
if [[ $? -ne 0 ]]; then
    echo "エラー: 仮想環境のアクティベートに失敗しました"
    exit 1
fi
echo "仮想環境をアクティベートしました"

# 依存関係のインストール
echo "依存パッケージをインストールしています..."
pip install --upgrade pip
pip install -r requirements.txt
if [[ $? -ne 0 ]]; then
    echo "エラー: 依存パッケージのインストールに失敗しました"
    exit 1
fi

# 設定ファイルの準備
mkdir -p data
if [ ! -f "data/config.json" ]; then
    echo "設定ファイルのテンプレートを作成しています..."
    cat > data/config.json << INNER_EOL
{
  "claude_api_key": "",
  "perplexity_api_key": "",
  "tracking_sheet_id": "",
  "drive_folder_id": "",
  "letter_template": "templates/letter_template.md",
  "receipt_template": "templates/receipt_template.md",
  "output_dir": "output"
}
INNER_EOL
fi

# API設定ファイルの準備
if [ ! -f "api_keys.json" ]; then
    echo "API設定ファイルのテンプレートを作成しています..."
    cat > api_keys.json << INNER_EOL
{
  "claude_api_key": "",
  "perplexity_api_key": ""
}
INNER_EOL
fi

# テンプレートファイルの準備
mkdir -p templates
if [ ! -f "templates/letter_template.md" ]; then
    echo "レターテンプレートを作成しています..."
    cat > templates/letter_template.md << INNER_EOL
# ご面会のお願い

\${company_name}
\${representative_title}
\${representative_name}様

拝啓 時下ますますご清栄のこととお慶び申し上げます。東大発3D＆AIスタートアップWOGO 代表の秦と申します。

このたび、貴社の\${business_understanding}を拝見し、大変興味を抱き、ご連絡を差し上げました。

弊社は創業以来、東京大学研究の3D技術をコアとした開発に注力してまいりましたが、近年注目を浴びる生成AI技術との統合により、従来は困難とされてきた未来をいよいよ現実のものとできると実感しております。

特に、貴社におかれましては、下記のような展望——

\${examples}

をともに実現し、新たな飛躍を生み出せるのではないかとワクワクしております！

つきましては、\${representative_name}様に他社様への支援事例をご紹介しつつ、ぜひ一度ご意見交換の機会を頂戴できればと存じます。15分ほどのオンライン面談でも、対面でのご相談でも構いませんので、ご都合をお聞かせいただけますと幸いです。

Mail: shin.koeru@wogo.ai  
Tel : 070-1390-2130

末筆ながら、ご多忙の折とは存じますが、くれぐれもご自愛ください。何卒ご検討のほどよろしくお願い申し上げます。

敬具

株式会社WOGO  
代表取締役 秦 竟超  
Mail: shin.koeru@wogo.ai
INNER_EOL
fi

if [ ! -f "templates/receipt_template.md" ]; then
    echo "受領書テンプレートを作成しています..."
    cat > templates/receipt_template.md << INNER_EOL
# 受　領　書

令和　　年　　月　　日

　　株式会社WOGO　　様




金　　\${total_amount}　　円也



　　　上記金額を正に受領いたしました。



　　　但し、　　　営業サポート業務の報酬　　　　として



　　[住所] 　　　　　　　　　　　　
[氏名] 　　　　　　　　　　　　


\${company_list}
INNER_EOL
fi

# サンプル入力ファイルの作成
if [ ! -f "testinput.tsv" ]; then
    echo "サンプル入力ファイルを作成しています..."
    cat > testinput.tsv << INNER_EOL
株式会社サンプル	東京都千代田区丸の内1-1-1	山田 太郎	代表取締役社長
株式会社テスト	大阪府大阪市北区梅田2-2-2	鈴木 一郎	代表取締役
INNER_EOL
fi

# ディレクトリ構造の作成
mkdir -p src/api src/models src/services src/integrations src/ui
mkdir -p results/address_verification results/technology_research results/cxo_letter

# 提供されたコードを移植
cat > src/batch_process.py << INNER_EOL
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
企業情報検索と文書生成スクリプト

SearchEnhancedLLMを使用して企業情報の検証と文書生成を行います。
入力されたTSVファイルから企業情報を読み取り、以下の処理を行います：
1. 企業の住所確認（住所が正しいかどうかをYes/Noで出力）
2. 企業のAI/3D設計技術などに関する取り組みの調査
3. 調査結果に基づいたCXOレターの生成

結果は3つの別々のTSVファイルに出力されます。
"""

import os
import csv
import json
from pathlib import Path
from datetime import datetime
from search_enhanced_llm import SearchEnhancedLLM


def ensure_format_compliance(system, original_response, format_instruction):
    """
    Claudeを通じて出力形式を再確認し、適合させる
    
    Args:
        system: SearchEnhancedLLMインスタンス
        original_response: 最初の回答
        format_instruction: 形式に関する指示
        
    Returns:
        形式に従った回答
    """
    prompt = f"""
以下の回答を、指定された形式に厳密に従って再構成してください：

回答: {original_response}

形式指示: {format_instruction}

形式に従った回答のみを出力してください。余計な説明は不要です。
"""
    
    result = system.query(
        user_query=prompt,
        search_first=False,  # 検索は不要
        save_results=False
    )
    
    return result["generated_text"].strip()


def process_company(system, company_name, address, representative_name, representative_title):
    """
    企業情報を処理して、住所確認と文書生成を行う
    
    Args:
        system: SearchEnhancedLLMインスタンス
        company_name: 企業名
        address: 住所
        representative_name: 代表者名
        representative_title: 代表者役職
        
    Returns:
        結果の辞書（住所確認結果、調査結果、文書など）
    """
    # 結果を格納する辞書
    result = {
        "company_name": company_name,
        "address": address,
        "representative_name": representative_name,
        "representative_title": representative_title,
        "address_verification": None,
        "technology_research": None,
        "cxo_letter": None,
        "error": None
    }
    
    try:
        print(f"\n===== {company_name}の処理を開始 =====")
        
        # 1. 住所の確認
        print(f"1. 住所確認中...")
        address_query = f"{company_name}の現在の本社所在地は{address}であっていますか？"
        address_result = system.query(
            user_query=address_query,
            save_results=True,
            output_dir="results/address_verification"
        )
        
        # 形式を確認（YesまたはNoのみを出力）
        format_instruction = "YesまたはNoのみを出力してください。余計な説明は不要です。"
        formatted_address_verification = ensure_format_compliance(
            system, 
            address_result["generated_text"], 
            format_instruction
        )
        
        result["address_verification"] = formatted_address_verification
        print(f"住所確認結果: {result['address_verification']}")
        
        # 2. 技術調査
        print(f"2. 技術調査中...")
        research_query = f"{address}に所在する「{company_name}」にCXOレターを執筆したい。以下の(1)を対応してください。(1)最初に、先方企業のAIと3D設計技術に関する取り組みをWeb上で幅広く調べ、出力して。どうしても見つからない場合には、当該企業の先端技術に対する推進の取り組みを複数挙げて。それすらも見つからない場合、当該企業の強み的な事業内容を調べ、出力して。"
        research_result = system.query(
            user_query=research_query,
            save_results=True,
            output_dir="results/technology_research"
        )
        
        # 技術調査結果を保存
        result["technology_research"] = research_result["generated_text"]
        print(f"技術調査完了")
        
        # 3. CXOレター生成
        print(f"3. CXOレター生成中...")
        letter_query = f"{address}に所在する「{company_name}」にCXOレターを執筆したい。以下の(2)に続きで対応してください。(2) 次に、以下の調査結果の中でインパクトが大きく興味深い内容にもとづき、以下のsentence Xの{{{{事業内容理解}}}}の箇所を、先方企業の取り組み（Webの検索結果）に合わせて書き換えたものを1文(1.5行程度)の端的なボリュームで、「最終出力：」に続けて出力して。\n\n調査結果：\n{result['technology_research']}\n\nsentence X = '''このたび、貴社の{{事業内容理解}}を拝見し、大変興味を抱き、ご連絡を差し上げました。'''"
        letter_result = system.query(
            user_query=letter_query,
            search_first=False,  # 既に検索済みの情報を使用するため
            save_results=True,
            output_dir="results/cxo_letter"
        )
        
        # 形式を確認（文章のみ出力）
        format_instruction = "「このたび、貴社の～ご連絡を差し上げました。」という完全な文章のみを出力してください。「最終出力：」などの接頭語は含めないでください。"
        formatted_letter = ensure_format_compliance(
            system, 
            letter_result["generated_text"], 
            format_instruction
        )
        
        result["cxo_letter"] = formatted_letter
        print(f"CXOレター生成完了")
        
        print(f"===== {company_name}の処理が完了しました =====\n")
        return result
        
    except Exception as e:
        error_msg = f"エラーが発生しました: {str(e)}"
        print(f"{company_name}の処理中にエラー: {error_msg}")
        result["error"] = error_msg
        return result


def process_tsv_file(input_file):
    """
    TSVファイルを処理して、結果を複数のTSVファイルに出力する
    
    Args:
        input_file: 入力TSVファイルのパス
    """
    # 設定ファイルの検索
    config_py_path = "config.py"
    config_json_path = "api_keys.json"
    
    # システムの初期化
    system = None
    if Path(config_py_path).is_file():
        print(f"Pythonファイル '{config_py_path}' から設定を読み込みます...")
        try:
            system = SearchEnhancedLLM.load_from_python(config_py_path, verbose=True)
            print("設定の読み込みに成功しました")
        except Exception as e:
            print(f"Pythonファイルからの読み込みに失敗しました: {str(e)}")
    
    if system is None and Path(config_json_path).is_file():
        print(f"JSONファイル '{config_json_path}' から設定を読み込みます...")
        try:
            system = SearchEnhancedLLM.load_from_json(config_json_path, verbose=True)
            print("設定の読み込みに成功しました")
        except Exception as e:
            print(f"JSONファイルからの読み込みに失敗しました: {str(e)}")
    
    if system is None:
        # 環境変数からAPIキーを取得
        print("環境変数から設定を読み込みます...")
        try:
            system = SearchEnhancedLLM(verbose=True)
            print("環境変数からの読み込みに成功しました")
        except Exception as e:
            print(f"環境変数からの読み込みに失敗しました: {str(e)}")
            print("APIキーの設定が必要です。config.pyまたはapi_keys.jsonを設定するか、環境変数を設定してください。")
            return
    
    # タイムスタンプを生成（ファイル名用）
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # 出力ディレクトリとファイル名の設定
    os.makedirs("results", exist_ok=True)
    os.makedirs("results/address_verification", exist_ok=True)
    os.makedirs("results/technology_research", exist_ok=True)
    os.makedirs("results/cxo_letter", exist_ok=True)
    
    address_file = f"results/address_verification_{timestamp}.tsv"
    research_file = f"results/technology_research_{timestamp}.tsv"
    letter_file = f"results/cxo_letter_{timestamp}.tsv"
    
    # 入力TSVファイルの読み込み
    results = []
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
            for line in lines:
                parts = line.strip().split('\t')
                
                if len(parts) >= 2:
                    company_name = parts[0].strip()
                    address = parts[1].strip()
                    
                    # 代表者情報（ある場合）
                    representative_name = parts[2].strip() if len(parts) > 2 else ""
                    representative_title = parts[3].strip().split(" ")[0] if len(parts) > 3 else ""
                    
                    print(f"処理中: {company_name}")
                    result = process_company(system, company_name, address, representative_name, representative_title)
                    results.append(result)
                else:
                    print(f"警告: 行の形式が正しくありません: {line}")
    except Exception as e:
        print(f"TSVファイルの読み込み中にエラーが発生しました: {str(e)}")
        return
    
    # 住所確認結果の出力
    try:
        with open(address_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            writer.writerow(["企業名", "住所", "住所確認結果(Yes/No)"])
            for result in results:
                writer.writerow([
                    result["company_name"],
                    result["address"],
                    result["address_verification"]
                ])
        print(f"住所確認結果を {address_file} に保存しました")
    except Exception as e:
        print(f"住所確認結果の出力中にエラーが発生しました: {str(e)}")
    
    # 調査結果の出力
    try:
        with open(research_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            writer.writerow(["企業名", "調査結果"])
            for result in results:
                writer.writerow([
                    result["company_name"],
                    result["technology_research"]
                ])
        print(f"調査結果を {research_file} に保存しました")
    except Exception as e:
        print(f"調査結果の出力中にエラーが発生しました: {str(e)}")
    
    # CXOレターの出力
    try:
        with open(letter_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            writer.writerow(["企業名", "CXOレター"])
            for result in results:
                writer.writerow([
                    result["company_name"],
                    result["cxo_letter"]
                ])
        print(f"CXOレターを {letter_file} に保存しました")
    except Exception as e:
        print(f"CXOレターの出力中にエラーが発生しました: {str(e)}")
    
    print(f"\n処理完了。結果は以下のファイルに保存されました：")
    print(f"- 住所確認: {address_file}")
    print(f"- 調査結果: {research_file}")
    print(f"- CXOレター: {letter_file}")


def main():
    input_file = "testinput.tsv"
    
    if not Path(input_file).is_file():
        print(f"エラー: 入力ファイル '{input_file}' が見つかりません。")
        return
    
    process_tsv_file(input_file)


if __name__ == "__main__":
    main()
INNER_EOL

# SearchEnhancedLLMモジュールを作成
cat > src/search_enhanced_llm.py << INNER_EOL
import os
import json
import anthropic
from datetime import datetime

class SearchEnhancedLLM:
    """
    検索機能を強化したLLMインターフェース
    Claude APIとPerplexity APIを組み合わせて使用します
    """
    
    def __init__(self, claude_api_key=None, perplexity_api_key=None, verbose=False):
        """
        初期化
        
        Args:
            claude_api_key: Claude API キー（デフォルトは環境変数から取得）
            perplexity_api_key: Perplexity API キー（デフォルトは環境変数から取得）
            verbose: 詳細なログを出力するかどうか
        """
        self.verbose = verbose
        
        # Claude API キーの設定
        self.claude_api_key = claude_api_key or os.environ.get("CLAUDE_API_KEY")
        if not self.claude_api_key:
            raise ValueError("Claude API キーが設定されていません")
            
        # Perplexity API キーの設定
        self.perplexity_api_key = perplexity_api_key or os.environ.get("PERPLEXITY_API_KEY")
        if not self.perplexity_api_key:
            raise ValueError("Perplexity API キーが設定されていません")
            
        # Claude クライアントの初期化
        self.client = anthropic.Anthropic(api_key=self.claude_api_key)
        
        if self.verbose:
            print("SearchEnhancedLLM 初期化完了")
    
    @classmethod
    def load_from_python(cls, config_path, verbose=False):
        """
        Pythonファイルから設定を読み込む
        
        Args:
            config_path: 設定ファイルのパス
            verbose: 詳細なログを出力するかどうか
            
        Returns:
            SearchEnhancedLLMインスタンス
        """
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("config", config_path)
            config = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(config)
            
            claude_api_key = getattr(config, "CLAUDE_API_KEY", None)
            perplexity_api_key = getattr(config, "PERPLEXITY_API_KEY", None)
            
            return cls(claude_api_key, perplexity_api_key, verbose)
        except Exception as e:
            if verbose:
                print(f"設定ファイルの読み込みエラー: {str(e)}")
            raise
    
    @classmethod
    def load_from_json(cls, config_path, verbose=False):
        """
        JSONファイルから設定を読み込む
        
        Args:
            config_path: 設定ファイルのパス
            verbose: 詳細なログを出力するかどうか
            
        Returns:
            SearchEnhancedLLMインスタンス
        """
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                
            claude_api_key = config.get("claude_api_key")
            perplexity_api_key = config.get("perplexity_api_key")
            
            return cls(claude_api_key, perplexity_api_key, verbose)
        except Exception as e:
            if verbose:
                print(f"設定ファイルの読み込みエラー: {str(e)}")
            raise
    
    def query(self, user_query, search_first=True, save_results=False, output_dir=None):
        """
        クエリを実行
        
        Args:
            user_query: ユーザークエリ
            search_first: 検索を先に実行するかどうか
            save_results: 結果を保存するかどうか
            output_dir: 結果を保存するディレクトリ
            
        Returns:
            dict: 生成されたテキストと検索結果を含む辞書
        """
        if self.verbose:
            print(f"クエリ: {user_query}")
        
        search_results = None
        if search_first:
            # Perplexity APIを使用した検索（実際の実装ではここを変更）
            # この実装では検索を省略し、Claude APIですべて処理
            if self.verbose:
                print("検索をスキップ（模擬実装）")
        
        # Claude APIでクエリを実行
        try:
            message = self.client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=2000,
                temperature=0.0,
                messages=[
                    {"role": "user", "content": user_query}
                ]
            )
            
            generated_text = message.content[0].text
            
            if self.verbose:
                print(f"応答: {generated_text[:100]}...")
            
            # 結果を保存
            if save_results and output_dir:
                self.save_result(user_query, generated_text, search_results, output_dir)
            
            return {
                "generated_text": generated_text,
                "search_results": search_results
            }
            
        except Exception as e:
            if self.verbose:
                print(f"APIリクエストエラー: {str(e)}")
            raise
    
    def save_result(self, query, generated_text, search_results, output_dir):
        """
        結果を保存
        
        Args:
            query: クエリ
            generated_text: 生成されたテキスト
            search_results: 検索結果
            output_dir: 保存先ディレクトリ
        """
        try:
            os.makedirs(output_dir, exist_ok=True)
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{output_dir}/result_{timestamp}.json"
            
            result = {
                "query": query,
                "generated_text": generated_text,
                "search_results": search_results,
                "timestamp": timestamp
            }
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
                
            if self.verbose:
                print(f"結果を保存しました: {filename}")
                
        except Exception as e:
            if self.verbose:
                print(f"結果の保存エラー: {str(e)}")
INNER_EOL

echo "セットアップが完了しました！"
echo "次のコマンドで開発サーバーを起動できます: python src/main.py"
echo "バッチ処理を実行するには: python src/batch_process.py"