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
