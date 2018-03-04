from mock import patch


class A(object):
    @staticmethod
    def jiayou(a, b):
        print(a, b)


if __name__ == "__main__":
    with patch.object(A, "jiayou", autospec=True) as jiayou:
        jiayou.return_value = "ceshi"
        print(A.jiayou(1, 2))
