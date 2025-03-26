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
